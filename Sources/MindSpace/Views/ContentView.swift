import SwiftUI
import SwiftData

public enum AppTab: Int, CaseIterable, Identifiable {
    case today = 0
    case library = 1
    case progress = 2
    case settings = 3
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .today: return "Today"
        case .library: return "Library"
        case .progress: return "Progress"
        case .settings: return "Settings"
        }
    }
    
    public var iconName: String {
        switch self {
        case .today: return "house.fill"
        case .library: return "books.vertical.fill"
        case .progress: return "chart.bar.xaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

/// Root application view hosting the 4 cosmic tabs and persistent floating mini-player dock.
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    
    @State private var selectedTab: AppTab = .today
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            CosmosTheme.spaceBackground.ignoresSafeArea()
            
            // MARK: - Tab Views
            Group {
                switch selectedTab {
                case .today:
                    TodayView()
                case .library:
                    LibraryView()
                case .progress:
                    ProgressDashboardView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // MARK: - Floating Mini-Player & Custom Bottom Tab Bar
            VStack(spacing: 0) {
                // Mini-Player Strip
                MiniPlayerView()
                
                // Custom Cosmic Tab Bar
                customTabBar
            }
        }
        .fullScreenCover(isPresented: $playbackEngine.isFullPlayerPresented) {
            MeditationPlayerView()
        }
        .onAppear {
            setupPlaybackCallbacks()
        }
    }
    
    // MARK: - Custom Cosmic Tab Bar
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(selectedTab == tab ? CosmosTheme.cosmicPurple : CosmosTheme.textSecondary)
                        
                        Text(tab.title)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular, design: .rounded))
                            .foregroundColor(selectedTab == tab ? CosmosTheme.textPrimary : CosmosTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            CosmosTheme.spaceCard
                .overlay(
                    Rectangle()
                        .fill(CosmosTheme.spaceCardBorder)
                        .frame(height: 1),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private func setupPlaybackCallbacks() {
        playbackEngine.onSessionCompleted = { track, playedSeconds in
            let isQualifying = playbackEngine.accumulator?.hasQualified ?? true
            let container = modelContext.container
            Task {
                let actor = ProgressActor(modelContainer: container)
                try? await actor.recordCompletion(
                    sessionStableId: track.id,
                    courseId: track.courseName,
                    playedSeconds: playedSeconds,
                    isQualifying: isQualifying
                )
            }
        }
    }
}
