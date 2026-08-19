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
        
        do {
            let schema = Schema([
                CompletionEvent.self,
                PlaybackResume.self,
                FavoriteItem.self,
                UserSettings.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .preferredColorScheme(.dark)
        }
    }
}
