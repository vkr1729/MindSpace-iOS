import SwiftUI
import SwiftData

/// Bridges background persistence callbacks to the ContentView banner.
/// Single registration site (setupPlaybackCallbacks, onAppear) owns one instance.
/// Reports always hop to MainActor before touching @Published state.
final class PersistenceErrorRelay: ObservableObject, @unchecked Sendable {
    @Published var message: String?
    func report(_ text: String) {
        Task { @MainActor in self.message = text }
    }
}

/// Root application view hosting the 4 cosmic tabs, onboarding gate, and persistent mini-player dock.
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    @StateObject private var errorRelay = PersistenceErrorRelay()

    @Query private var settingsList: [UserSettings]

    @State private var selectedTab: AppTab = .today
    @State private var showOnboarding: Bool = false
    @State private var pendingImportURL: URL?
    @State private var todayPath = NavigationPath()
    @State private var libraryPath = NavigationPath()
    @State private var progressPath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    private let persistenceState: PersistenceState

    public init(persistenceState: PersistenceState = .healthy) {
        self.persistenceState = persistenceState
    }

    private var hasCompletedOnboarding: Bool {
        settingsList.first?.hasCompletedOnboarding ?? false
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            CosmosTheme.spaceBackground.ignoresSafeArea()

            // MARK: - Tab Views (kept alive so tab switches preserve state)
            Group {
                TodayView(path: $todayPath)
                    .opacity(selectedTab == .today ? 1 : 0)
                    .allowsHitTesting(selectedTab == .today)
                LibraryView(path: $libraryPath)
                    .opacity(selectedTab == .library ? 1 : 0)
                    .allowsHitTesting(selectedTab == .library)
                ProgressDashboardView(path: $progressPath)
                    .opacity(selectedTab == .progress ? 1 : 0)
                    .allowsHitTesting(selectedTab == .progress)
                SettingsView(path: $settingsPath)
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // MARK: - Floating Mini-Player & Custom Bottom Tab Bar
            VStack(spacing: 0) {
                if persistenceState != .healthy || errorRelay.message != nil {
                    persistenceBanner
                }
                // Mini-Player Strip
                MiniPlayerView()

                // Custom Cosmic Tab Bar
                customTabBar
            }
            .fullScreenCover(isPresented: $playbackEngine.isFullPlayerPresented) {
                MeditationPlayerView()
            }
            .sheet(item: Binding(
                get: { playbackEngine.lastCompletionInfo },
                set: { if $0 == nil { playbackEngine.acknowledgeLastCompletion() } }
            )) { info in
                CompletionView(
                    completionId: info.completionId,
                    sessionTitle: info.track.title,
                    courseName: info.track.courseName,
                    durationMinutes: info.actualMinutes,
                    isQualifying: info.isQualifying,
                    finalizedByStopOrSwitch: info.finalizedByStopOrSwitch,
                    isPersisted: info.isPersisted,
                    onDismiss: { playbackEngine.acknowledgeLastCompletion() }
                )
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            setupPlaybackCallbacks()
            checkOnboardingStatus()
            playbackEngine.restoreSleepTimerIfNeeded()
            NotificationScheduler.shared.reconcileReminderSetting(modelContext: modelContext)
            flushCompletionOutbox()
        }
        .onChange(of: settingsList) { _, newList in
            if let settings = newList.first, !settings.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                playbackEngine.saveCurrentResumePosition()
                flushCompletionOutbox()
            } else if newPhase == .active {
                NotificationScheduler.shared.reconcileReminderSetting(modelContext: modelContext)
                flushCompletionOutbox()
            }
        }
        .onOpenURL { url in
            pendingImportURL = url
        }
        .sheet(item: Binding(
            get: { pendingImportURL.map { ImportURLWrapper(url: $0) } },
            set: { pendingImportURL = $0?.url }
        )) { wrapper in
            BackupImportView(sourceURL: wrapper.url) {
                pendingImportURL = nil
            }
        }
    }

    private var persistenceBanner: some View {
        let message: String
        if let reported = errorRelay.message {
            message = reported
        } else if persistenceState == .inMemory {
            message = "Storage unavailable — progress is NOT being saved. Restart the app; nothing is written while this banner shows."
        } else {
            message = "Your history couldn't be opened, so the app started fresh. Your old data was kept — export a backup from Settings before reinstalling."
        }
        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(CosmosTheme.solarCoral)
            Text(message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(CosmosTheme.textPrimary)
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CosmosTheme.solarCoral.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CosmosTheme.solarCoral.opacity(0.5), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private struct ImportURLWrapper: Identifiable {
        let id = UUID()
        let url: URL
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

    private func flushCompletionOutbox() {
        guard persistenceState == .healthy else { return }
        let container = modelContext.container
        let errorRelay = self.errorRelay
        Task {
            let actor = ProgressActor(modelContainer: container)
            do {
                let remaining = try await actor.flushPendingCompletions()
                if remaining > 0 {
                    await MainActor.run {
                        errorRelay.report("Some saved sessions still need to sync to your history — they'll keep retrying.")
                    }
                }
            } catch {
                await MainActor.run {
                    errorRelay.report("Some saved sessions still need to sync to your history — they'll keep retrying.")
                }
            }
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
        let container = modelContext.container
        let persistenceState = self.persistenceState
        let errorRelay = self.errorRelay

        playbackEngine.onSessionCompleted = { track, playedSeconds, isQualifying, completionId in
            let stampedAt = Date()
            Task {
                guard persistenceState == .healthy else {
                    await MainActor.run {
                        errorRelay.report("Storage unavailable — this session was NOT saved.")
                    }
                    return
                }
                let actor = ProgressActor(modelContainer: container)
                do {
                    try await actor.recordCompletion(
                        id: completionId,
                        sessionStableId: track.id,
                        courseId: track.courseName,
                        playedSeconds: playedSeconds,
                        isQualifying: isQualifying,
                        contentType: track.contentType,
                        reflection: nil,
                        timestamp: stampedAt
                    )
                    await MainActor.run {
                        playbackEngine.markLastCompletionPersisted(id: completionId)
                    }
                } catch {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    do {
                        try await actor.recordCompletion(
                            id: completionId,
                            sessionStableId: track.id,
                            courseId: track.courseName,
                            playedSeconds: playedSeconds,
                            isQualifying: isQualifying,
                            contentType: track.contentType,
                            reflection: nil,
                            timestamp: stampedAt
                        )
                        await MainActor.run {
                            playbackEngine.markLastCompletionPersisted(id: completionId)
                        }
                    } catch {
                        do {
                            try await actor.enqueuePendingCompletion(
                                id: completionId,
                                sessionStableId: track.id,
                                courseId: track.courseName,
                                playedSeconds: playedSeconds,
                                isQualifying: isQualifying,
                                contentType: track.contentType,
                                timestamp: stampedAt,
                                timeZoneIdentifier: TimeZone.current.identifier,
                                gmtOffsetSeconds: TimeZone.current.secondsFromGMT()
                            )
                            await MainActor.run {
                                errorRelay.report("Couldn't save your session yet — it's queued and will retry automatically.")
                            }
                        } catch {
                            errorRelay.report("Couldn't save your session, and the retry queue is unavailable. Your history for this session was NOT saved.")
                        }
                    }
                }
            }
        }

        playbackEngine.onSaveResume = { track, position, accumulatedListenedSeconds in
            Task {
                let actor = ProgressActor(modelContainer: container)
                do {
                    try await actor.updateResumePosition(
                        sessionStableId: track.id,
                        relativePath: track.relativePath,
                        title: track.title,
                        courseName: track.courseName,
                        position: position,
                        duration: track.duration,
                        accumulatedListenedSeconds: accumulatedListenedSeconds
                    )
                } catch {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    do {
                        try await actor.updateResumePosition(
                            sessionStableId: track.id,
                            relativePath: track.relativePath,
                            title: track.title,
                            courseName: track.courseName,
                            position: position,
                            duration: track.duration,
                            accumulatedListenedSeconds: accumulatedListenedSeconds
                        )
                    } catch {
                        errorRelay.report("Couldn't save resume position. It will retry while this session is open.")
                    }
                }
            }
        }

        playbackEngine.onClearResume = { sessionId in
            // Guard already armed synchronously in finalizeCurrentSession
            // (same MainActor); just perform the delete off-main.
            Task {
                let actor = ProgressActor(modelContainer: container)
                try? await actor.deleteResume(sessionStableId: sessionId)
            }
        }
    }
}

/// Handles `.mindspace` files opened from Files/share sheet.
private struct BackupImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismissSheet
    let sourceURL: URL
    let onDone: () -> Void

    @State private var message: String = "Import this backup?"
    @State private var document: MindSpaceBackupDocument?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(message)
                    .padding()
                if document != nil {
                    Button("Merge import") {
                        do {
                            guard let doc = document else { return }
                            try ProgressTransferManager.shared.applyImport(
                                document: doc,
                                modelContext: modelContext,
                                isCleanRestore: false
                            )
                            message = "Imported successfully."
                            HapticService.shared.success()
                            dismissSheet()
                            onDone()
                        } catch {
                            message = "Import error: \(error.localizedDescription)"
                        }
                    }
                    Button("Clean restore") {
                        do {
                            guard let doc = document else { return }
                            try ProgressTransferManager.shared.applyImport(
                                document: doc,
                                modelContext: modelContext,
                                isCleanRestore: true
                            )
                            message = "Restored successfully."
                            HapticService.shared.success()
                            dismissSheet()
                            onDone()
                        } catch {
                            message = "Import error: \(error.localizedDescription)"
                        }
                    }
                }
                Button("Close") {
                    dismissSheet()
                    onDone()
                }
            }
            .navigationTitle("Import Backup")
            .onAppear {
                do {
                    document = try ProgressTransferManager.shared.parseBackupDocument(gainingAccessTo: sourceURL)
                } catch {
                    message = "Couldn't read that .mindspace file: \(error.localizedDescription)"
                }
            }
        }
    }
}
