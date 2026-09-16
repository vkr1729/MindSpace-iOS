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

        let schema = Schema([
            CompletionEvent.self,
            PlaybackResume.self,
            FavoriteItem.self,
            UserSettings.self
        ])
        _ = StoreSchema.version

        var resolvedContainer: ModelContainer?
        var resolvedState: PersistenceState = .healthy

        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            resolvedContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            let nsError = error as NSError
            let isMigrationError = nsError.domain == NSCocoaErrorDomain
                && (nsError.code == 134110 || nsError.code == 134130 || nsError.code == 134140)

            if isMigrationError,
               let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storeURL = appSupport.appendingPathComponent("default.store")
                let shmURL = appSupport.appendingPathComponent("default.store-shm")
                let walURL = appSupport.appendingPathComponent("default.store-wal")
                let backupURL = appSupport.appendingPathComponent(
                    "default.store.corrupt_\(Int(Date().timeIntervalSince1970))"
                )
                try? FileManager.default.moveItem(at: storeURL, to: backupURL)
                try? FileManager.default.removeItem(at: shmURL)
                try? FileManager.default.removeItem(at: walURL)

                let retryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                if let retried = try? ModelContainer(for: schema, configurations: [retryConfig]) {
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
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                self.container = try ModelContainer(for: schema, configurations: [memoryConfig])
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
        let context = container.mainContext
        var fetchDescriptor = FetchDescriptor<UserSettings>()
        fetchDescriptor.fetchLimit = 1
        if let existing = try? context.fetch(fetchDescriptor), existing.isEmpty {
            let initial = UserSettings()
            context.insert(initial)
            try? context.save()
        }
    }
}
