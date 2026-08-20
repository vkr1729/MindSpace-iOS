import SwiftUI
import SwiftData

/// Screen 1: Elevated Today Screen & Cosmic Orbit Hub
/// Reference: Mock Screen Codex.png & UI/UX Pro Max Design Intelligence
public struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var catalogService = CatalogService.shared
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    
    @Query(sort: \CompletionEvent.timestamp, order: .reverse) private var completionEvents: [CompletionEvent]
    @Query(sort: \PlaybackResume.updatedAt, order: .reverse) private var resumes: [PlaybackResume]
    @Query private var settingsList: [UserSettings]
    
    @State private var dailyJourneyItems: [DailyJourneyItem] = []
    @State private var isShowingReminderSheet = false
    
    public init() {}
    
    private var currentSettings: UserSettings {
        settingsList.first ?? UserSettings()
    }
    
    private var lifetimeCompletedSessionIDs: Set<String> {
        Set(completionEvents.filter { $0.isQualifyingMeditation }.map { $0.sessionStableId })
    }
    
    private var todayCompletedSessionIDs: Set<String> {
        let calendar = Calendar.current
        let today = Date()
        let todayKey = DateFormatterCache.dayKey(from: today)
        return Set(
            completionEvents
                .filter { $0.isQualifyingMeditation && DateFormatterCache.dayKey(from: $0.timestamp, timeZoneIdentifier: $0.timeZoneIdentifier) == todayKey }
                .map { $0.sessionStableId }
        )
    }
    
    private var timeGreeting: (greeting: String, prompt: String, icon: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return ("Good morning", "Start your day with presence.", "sun.max.fill")
        } else if hour < 17 {
            return ("Good afternoon", "Pause and center yourself.", "sun.haze.fill")
        } else {
            return ("Good evening", "Take a breath. You're here.", "moon.stars.fill")
        }
    }
    
    private var orbitStats: OrbitStats {
        let passes = currentSettings.compassionPassCount
        let lastPassDate = currentSettings.lastUsedCompassionPassDate
        return OrbitCalculator().calculateStats(
            events: completionEvents,
            existingCompassionPasses: passes,
            lastUsedPassDate: lastPassDate
        )
    }
    
    private var recommendations: [RecommendedItem] {
        RecommendationEngine.shared.getRecommendations(
            manifest: catalogService.manifest,
            settings: currentSettings,
            completedSessionIDs: lifetimeCompletedSessionIDs
        )
    }
    
    /// Featured daily sleep sound based on day of the year (curated strictly to 10m, 30m, 60m)
    private var dailySleepSound: (soundName: String, sessions: [SingleSession])? {
        guard let sleepCat = catalogService.manifest?.singlesCategories.first(where: { $0.name == "Sleep Sounds" }) else {
            return nil
        }
        
        var soundGroups: [String: [SingleSession]] = [:]
        for session in sleepCat.sessions {
            let components = session.title.components(separatedBy: " - ")
            let groupName = components.count >= 2 ? components[1] : session.title
            soundGroups[groupName, default: []].append(session)
        }
        
        let keys = soundGroups.keys.sorted()
        guard !keys.isEmpty else { return nil }
        
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let selectedKey = keys[dayOfYear % keys.count]
        
        let allowedMinutes: Set<Int> = [10, 30, 60]
        let sessions = (soundGroups[selectedKey] ?? [])
            .filter { session in
                let mins = Int(round(session.duration / 60.0))
                return allowedMinutes.contains(mins)
            }
            .sorted(by: { $0.duration < $1.duration })
        return (selectedKey, sessions)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                CosmosTheme.spaceBackground.ignoresSafeArea()
                
                // Subtle top background aura
                VStack {
                    LinearGradient(
                        colors: [CosmosTheme.cosmicPurple.opacity(0.18), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 260)
                    .ignoresSafeArea()
                    Spacer()
                }
                
                mainContentScrollView
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isShowingReminderSheet) {
                MindfulReminderSheet()
            }
            .onAppear {
                buildDailyJourney()
            }
            .onChange(of: completionEvents) { _, _ in
                buildDailyJourney()
            }
        }
    }
    
    private var mainContentScrollView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                headerBar
                streakHeroSection
                storageNoticeCard
                resumeSection
                dailyJourneySection
                
                if !recommendations.isEmpty {
                    recommendationsSection
                }
                
                if let sleepInfo = dailySleepSound {
                    dailySleepSection(title: sleepInfo.soundName, sessions: sleepInfo.sessions)
                        .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 90)
            }
        }
    }
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MindSpace")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                HStack(spacing: 4) {
                    Image(systemName: timeGreeting.icon)
                        .font(.system(size: 11))
                        .foregroundColor(CosmosTheme.starlightGold)
                    Text("\(timeGreeting.greeting) • \(timeGreeting.prompt)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                HapticService.shared.light()
                isShowingReminderSheet = true
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: currentSettings.reminderEnabled ? "bell.fill" : "bell")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(currentSettings.reminderEnabled ? CosmosTheme.starlightGold : CosmosTheme.textSecondary)
                        .frame(width: 42, height: 42)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                    
                    if currentSettings.reminderEnabled {
                        Circle()
                            .fill(CosmosTheme.starlightGold)
                            .frame(width: 8, height: 8)
                            .offset(x: -2, y: 2)
                    }
                }
            }
            .buttonStyle(.cosmicPressable)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    @ViewBuilder
    private var streakHeroSection: some View {
        if !currentSettings.hideStreak {
            OrbitArcGaugeView(
                currentStreak: orbitStats.currentStreak,
                milestoneDays: orbitStats.nextMilestoneDays,
                totalMinutes: orbitStats.totalMindfulMinutes,
                passesAvailable: orbitStats.compassionPassesAvailable
            )
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var storageNoticeCard: some View {
        if LibraryPathResolver.shared.getLibraryStorageSizeBytes() == 0 {
            CosmicCard(padding: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(CosmosTheme.moonLavender)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Content Setup Available")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                        Text("Transfer your 15.81 GB library anytime via USB or Files app. Catalog browsing is 100% active.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var resumeSection: some View {
        if let latestResume = resumes.first {
            resumeCard(latestResume)
                .padding(.horizontal, 20)
        }
    }
    
    private var dailyJourneySection: some View {
        DailyJourneyView(items: $dailyJourneyItems, onSelectTrack: { track in
            handleTrackTap(track: track)
        })
        .padding(.horizontal, 20)
    }
    
    // MARK: - Recommendations Section
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recommended for You")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recommendations) { item in
                        Button(action: {
                            HapticService.shared.medium()
                            playbackEngine.loadAndPlay(track: item.track)
                            playbackEngine.isFullPlayerPresented = true
                        }) {
                            CosmicCard(padding: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.subtitle)
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(CosmosTheme.moonLavender)
                                        Spacer()
                                        Text(item.durationLabel)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(CosmosTheme.textSecondary)
                                    }
                                    
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                        .lineLimit(1)
                                    
                                    Text(item.reason)
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(CosmosTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 200)
                            }
                        }
                        .buttonStyle(.cosmicPressable)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Resume Card
    private func resumeCard(_ resume: PlaybackResume) -> some View {
        CosmicCard(padding: 14) {
            HStack(spacing: 12) {
                Button(action: {
                    HapticService.shared.medium()
                    let track = PlayableTrack(
                        id: resume.sessionStableId,
                        title: resume.sessionTitle,
                        courseName: resume.courseName,
                        relativePath: resume.relativePath,
                        duration: resume.durationSeconds,
                        contentType: "meditation"
                    )
                    playbackEngine.loadAndPlay(
                        track: track,
                        startPosition: resume.lastPositionSeconds,
                        accumulatedListenedSeconds: resume.accumulatedListenedSeconds,
                        startInAudioPhase: true
                    )
                    playbackEngine.isFullPlayerPresented = true
                }) {
                    ZStack {
                        Circle()
                            .fill(CosmosTheme.cosmicPurple)
                            .frame(width: 44, height: 44)
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Resume where you left off")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(CosmosTheme.moonLavender)
                    
                    Text(resume.sessionTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                        .lineLimit(1)
                    
                    let remSecs = max(0, resume.durationSeconds - resume.lastPositionSeconds)
                    let remMins = max(1, Int(round(remSecs / 60.0)))
                    Text("\(remMins) min remaining")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Sleep Sound Section
    private func dailySleepSection(title: String, sessions: [SingleSession]) -> some View {
        CosmicCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(CosmosTheme.cosmicPurple.opacity(0.3))
                            .frame(width: 36, height: 36)
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(CosmosTheme.starlightGold)
                            .font(.system(size: 16))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tonight's Wind Down")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(CosmosTheme.moonLavender)
                        Text(title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                    }
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    ForEach(sessions) { session in
                        let mins = Int(round(session.duration / 60.0))
                        Button(action: {
                            HapticService.shared.medium()
                            let track = PlayableTrack(
                                id: session.id,
                                title: session.title,
                                courseName: "Sleep Sounds",
                                relativePath: session.relativePath,
                                duration: session.duration,
                                contentType: "sleep"
                            )
                            playbackEngine.loadAndPlay(track: track)
                            playbackEngine.isFullPlayerPresented = true
                        }) {
                            Text("\(mins) min")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(CosmosTheme.spaceCardBorder)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.cosmicPressable)
                    }
                }
            }
        }
    }
    
    private func handleTrackTap(track: PlayableTrack) {
        HapticService.shared.medium()
        playbackEngine.loadAndPlay(track: track)
        playbackEngine.isFullPlayerPresented = true
    }
    
    private func buildDailyJourney() {
        var items: [DailyJourneyItem] = []
        
        let activeCourse = catalogService.manifest?.categories.first?.courses.first
        var nextSessionToPlay: CatalogSession?
        if let course = activeCourse {
            nextSessionToPlay = course.sessions.first(where: { !lifetimeCompletedSessionIDs.contains($0.id) }) ?? course.sessions.first
        }
        
        if let course = activeCourse, let session = nextSessionToPlay {
            let track = PlayableTrack(
                id: session.id,
                title: session.title,
                courseName: course.name,
                relativePath: session.relativePath,
                duration: session.duration,
                videoAttachmentPath: session.videoAttachments?.first?.relativePath,
                dayNumber: session.dayNumber,
                contentType: "meditation"
            )
            let isDoneToday = todayCompletedSessionIDs.contains(session.id)
            items.append(DailyJourneyItem(
                id: "journey_1",
                title: "\(isDoneToday ? "Completed" : "Continue") \(course.name) — Day \(session.dayNumber)",
                durationLabel: "\(max(1, Int(session.duration / 60))) min",
                isPrimaryAction: true,
                isCompleted: isDoneToday,
                playableTrack: track
            ))
        } else {
            items.append(DailyJourneyItem(
                id: "journey_1",
                title: "Start Basics — Day 1",
                durationLabel: "10 min",
                isPrimaryAction: true,
                isCompleted: false
            ))
        }
        
        if let unwindCat = catalogService.manifest?.singlesCategories.first(where: { $0.name == "Unwind" }),
           let reset5Min = findResetSession(in: unwindCat) ?? unwindCat.sessions.first {
            let track = PlayableTrack(
                id: reset5Min.id,
                title: reset5Min.title,
                courseName: "Unwind",
                relativePath: reset5Min.relativePath,
                duration: reset5Min.duration,
                contentType: "meditation"
            )
            let isDone2 = todayCompletedSessionIDs.contains(reset5Min.id)
            items.append(DailyJourneyItem(
                id: "journey_2",
                title: "\(isDone2 ? "Completed" : "") 5 min reset",
                durationLabel: "5 min",
                isPrimaryAction: false,
                isCompleted: isDone2,
                playableTrack: track
            ))
        } else {
            items.append(DailyJourneyItem(
                id: "journey_2",
                title: "5 min reset",
                durationLabel: "5 min",
                isPrimaryAction: false,
                isCompleted: false
            ))
        }
        
        let sleepCategory = catalogService.manifest?.singlesCategories.first(where: { $0.name.contains("Good Night") || $0.name.contains("Sleep") })
        if let nightSession = sleepCategory?.sessions.first {
            let track = PlayableTrack(
                id: nightSession.id,
                title: nightSession.title,
                courseName: "Sleep & Rest",
                relativePath: nightSession.relativePath,
                duration: nightSession.duration,
                contentType: "sleep"
            )
            let isDone3 = todayCompletedSessionIDs.contains(nightSession.id)
            items.append(DailyJourneyItem(
                id: "journey_3",
                title: "\(isDone3 ? "Completed" : "") Evening wind-down",
                durationLabel: "10 min",
                isPrimaryAction: false,
                isCompleted: isDone3,
                playableTrack: track
            ))
        } else {
            items.append(DailyJourneyItem(
                id: "journey_3",
                title: "Evening wind-down",
                durationLabel: "10 min",
                isPrimaryAction: false,
                isCompleted: false
            ))
        }
        
        self.dailyJourneyItems = items
    }
    
    private func findResetSession(in category: SinglesCategory) -> SingleSession? {
        for session in category.sessions {
            let title = session.title.lowercased()
            if title.contains("reset") && (title.contains("5") || (session.duration >= 280 && session.duration <= 320)) {
                return session
            }
        }
        return nil
    }
}
