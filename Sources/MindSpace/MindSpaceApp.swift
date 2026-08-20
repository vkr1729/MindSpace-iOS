import SwiftUI
import SwiftData

@main
struct MindSpaceApp: App {
    let container: ModelContainer
    
    init() {
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
        
        // 1. Try standard persistent store
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            resolvedContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("Warning: Persistent ModelContainer failed: \(error.localizedDescription). Attempting store recovery...")
            
            // 2. Attempt store recovery for schema migration from prior builds
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storeURL = appSupport.appendingPathComponent("default.store")
                let shmURL = appSupport.appendingPathComponent("default.store-shm")
                let walURL = appSupport.appendingPathComponent("default.store-wal")
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: shmURL)
                try? FileManager.default.removeItem(at: walURL)
                
                let retryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                resolvedContainer = try? ModelContainer(for: schema, configurations: [retryConfig])
            }
        }
        
        // 3. Fallback to in-memory container to guarantee app launches under all conditions
        if let ready = resolvedContainer {
            self.container = ready
        } else {
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                self.container = try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                fatalError("Critical: Failed to create ModelContainer: \(error.localizedDescription)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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
