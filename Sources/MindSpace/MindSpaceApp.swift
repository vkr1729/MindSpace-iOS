import SwiftUI
import SwiftData

public enum PersistenceState: Sendable, Equatable {
    case healthy
    case recoveredFromBackup
    case inMemory
}

@main
struct MindSpaceApp: App {
    let container: ModelContainer
    let persistenceState: PersistenceState

    init() {
        LibraryPathResolver.shared.applyHardeningAndProtection()

        AudioSessionManager.shared.configureAudioSession()

        var resolvedContainer: ModelContainer?
        var resolvedState: PersistenceState = .healthy

        do {
            let config = ModelConfiguration(
                schema: Schema(versionedSchema: MindSpaceSchemaV1_1.self),
                isStoredInMemoryOnly: false
            )
            resolvedContainer = try ModelContainer(
                for: MindSpaceSchemaV1_1.self,
                migrationPlan: MindSpaceMigrationPlan.self,
                configurations: config
            )
        } catch {
            let nsError = error as NSError
            let isMigrationError = nsError.domain == NSCocoaErrorDomain
                && (nsError.code == 134110 || nsError.code == 134130 || nsError.code == 134140)

            if isMigrationError,
               let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storeURL = appSupport.appendingPathComponent(StoreSchema.storeName)
                let shmURL = appSupport.appendingPathComponent("\(StoreSchema.storeName)-shm")
                let walURL = appSupport.appendingPathComponent("\(StoreSchema.storeName)-wal")
                let backupURL = appSupport.appendingPathComponent(
                    "\(StoreSchema.storeName).corrupt_\(Int(Date().timeIntervalSince1970))"
                )
                if FileManager.default.fileExists(atPath: storeURL.path) {
                    try? FileManager.default.moveItem(at: storeURL, to: backupURL)
                }
                try? FileManager.default.removeItem(at: shmURL)
                try? FileManager.default.removeItem(at: walURL)

                let retryConfig = ModelConfiguration(
                    schema: Schema(versionedSchema: MindSpaceSchemaV1_1.self),
                    isStoredInMemoryOnly: false
                )
                if let retried = try? ModelContainer(
                    for: MindSpaceSchemaV1_1.self,
                    migrationPlan: MindSpaceMigrationPlan.self,
                    configurations: retryConfig
                ) {
                    resolvedContainer = retried
                    resolvedState = .recoveredFromBackup
                }
            } else {
                print("Warning: Persistent ModelContainer failed with a non-migration error (\(error)). Store left untouched; will retry in-memory only as a last resort.")
            }
        }

        if let ready = resolvedContainer {
            self.container = ready
            self.persistenceState = resolvedState
        } else {
            let memorySchema = Schema(versionedSchema: MindSpaceSchemaV1_1.self)
            let memoryConfig = ModelConfiguration(schema: memorySchema, isStoredInMemoryOnly: true)
            do {
                self.container = try ModelContainer(for: memorySchema, configurations: [memoryConfig])
                self.persistenceState = .inMemory
            } catch {
                fatalError("Critical: Failed to create ModelContainer: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(persistenceState: persistenceState)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .onAppear {
                    ensureInitialSettings()
                }
        }
    }

    @MainActor
    private func ensureInitialSettings() {
        _ = SettingsStore.fetchOrCreate(in: container.mainContext)
    }
}
