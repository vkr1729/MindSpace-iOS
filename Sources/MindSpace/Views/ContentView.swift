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

/// Root application view hosting four tabs, onboarding, and the mini-player.
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    
    @Query private var settingsList: [UserSettings]
    
    @State private var selectedTab: AppTab = .today
    @State private var showOnboarding: Bool = false

    private let persistenceIssue: String?
    
    public init(persistenceIssue: String? = nil) {
        self.persistenceIssue = persistenceIssue
    }
    
    private var hasCompletedOnboarding: Bool {
        settingsList.first?.hasCompletedOnboarding ?? false
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            MindSpaceTheme.background.ignoresSafeArea()
            
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
                    .fullScreenCover(isPresented: $playbackEngine.isFullPlayerPresented) {
                        MeditationPlayerView()
                    }
                
                // Bottom tab bar
                customTabBar
            }

            if let persistenceIssue {
                persistenceRecoveryView(message: persistenceIssue)
                    .zIndex(100)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            setupPlaybackCallbacks()
            checkOnboardingStatus()
        }
        .onChange(of: settingsList) { _, newList in
            if let settings = newList.first, !settings.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                playbackEngine.saveCurrentResumePosition()
            }
        }
    }

    private func persistenceRecoveryView(message: String) -> some View {
        ZStack {
            MindSpaceTheme.background.ignoresSafeArea()

            ContentUnavailableView {
                Label("Progress unavailable", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Text("Close and reopen MindSpace. If the problem continues, keep the app installed and restore from a known backup after the store is inspected.")
                    .font(.footnote)
                    .foregroundStyle(MindSpaceTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .foregroundStyle(MindSpaceTheme.textPrimary)
        }
        .accessibilityElement(children: .contain)
    }
    
    private func checkOnboardingStatus() {
        if let settings = settingsList.first {
            if !settings.hasCompletedOnboarding {
                showOnboarding = true
            }
        } else {
            showOnboarding = true
        }
    }
    
    // MARK: - Bottom tab bar
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button(action: {
                    if reduceMotion {
                        selectedTab = tab
                    } else {
                        withAnimation(.easeOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.title3)
                            .foregroundStyle(selectedTab == tab ? MindSpaceTheme.accent : MindSpaceTheme.textSecondary)
                            .accessibilityHidden(true)
                        
                        Text(tab.title)
                            .font(.caption2.weight(selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? MindSpaceTheme.textPrimary : MindSpaceTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                .accessibilityIdentifier("tab.\(tab.title.lowercased())")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            MindSpaceTheme.surface
                .overlay(
                    Rectangle()
                        .fill(MindSpaceTheme.divider)
                        .frame(height: 1),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private func setupPlaybackCallbacks() {
        let container = modelContext.container
        
        playbackEngine.onSessionCompleted = { track, playedSeconds, isQualifying, completionId in
            Task {
                let actor = ProgressActor(modelContainer: container)
                try? await actor.recordCompletion(
                    id: completionId,
                    sessionStableId: track.id,
                    courseId: track.courseName,
                    playedSeconds: playedSeconds,
                    isQualifying: isQualifying,
                    contentType: track.contentType,
                    reflection: nil,
                    timestamp: Date()
                )
            }
        }
        
        playbackEngine.onSaveResume = { track, position, accumulatedListenedSeconds in
            Task {
                let actor = ProgressActor(modelContainer: container)
                try? await actor.updateResumePosition(
                    sessionStableId: track.id,
                    relativePath: track.relativePath,
                    title: track.title,
                    courseName: track.courseName,
                    position: position,
                    duration: track.duration,
                    accumulatedListenedSeconds: accumulatedListenedSeconds
                )
            }
        }
        
        playbackEngine.onClearResume = { sessionId in
            Task {
                let actor = ProgressActor(modelContainer: container)
                try? await actor.deleteResume(sessionStableId: sessionId)
            }
        }
    }
}
