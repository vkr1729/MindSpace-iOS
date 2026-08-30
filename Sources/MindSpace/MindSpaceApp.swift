import SwiftUI
import SwiftData

@main
struct MindSpaceApp: App {
    let container: ModelContainer
    let persistenceIssue: String?
    
    init() {
        #if DEBUG
        UITestSupport.prepareFilesystem()
        #endif

        // Initialize Library Path Resolver & Sandboxing Hardening
        LibraryPathResolver.shared.applyHardeningAndProtection()
        
        // Configure Initial Audio Session
        AudioSessionManager.shared.configureAudioSession()
        
        let schema = Schema([
            CompletionEvent.self,
            PlaybackResume.self,
            FavoriteItem.self,
            UserSettings.self
        ])
        
        var resolvedContainer: ModelContainer?
        var persistentStoreError: Error?
        
        // 1. Try standard persistent store
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            resolvedContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            persistentStoreError = error
            print("Warning: Persistent ModelContainer could not be opened. Existing store files were preserved.")
        }
        
        // A temporary container lets the app present a recovery screen. The screen
        // blocks normal use so new progress cannot be written to disposable storage.
        if let ready = resolvedContainer {
            self.container = ready
            self.persistenceIssue = nil
        } else {
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                self.container = try ModelContainer(for: schema, configurations: [memoryConfig])
                self.persistenceIssue = persistentStoreError == nil
                    ? "MindSpace could not prepare progress storage."
                    : "MindSpace could not open the existing progress store. Your stored data was preserved."
            } catch {
                fatalError("Critical: Failed to create ModelContainer: \(error.localizedDescription)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(persistenceIssue: persistenceIssue)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .onAppear {
                    if persistenceIssue == nil {
                        ensureInitialSettings()
                    }
                }
        }
    }
    
    @MainActor
    private func ensureInitialSettings() {
        let context = container.mainContext
        #if DEBUG
        if UITestSupport.isEnabled {
            UITestSupport.prepareStore(context)
            return
        }
        #endif

        var fetchDescriptor = FetchDescriptor<UserSettings>()
        fetchDescriptor.fetchLimit = 1
        if let existing = try? context.fetch(fetchDescriptor), existing.isEmpty {
            let initial = UserSettings()
            context.insert(initial)
            try? context.save()
        }
    }
}
