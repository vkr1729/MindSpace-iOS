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
    
    public init() {}
    
    private var completedSessionIDs: Set<String> {
        Set(completionEvents.filter { $0.isQualifyingMeditation }.map { $0.sessionStableId })
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
        let passes = settingsList.first?.compassionPassCount ?? 0
        return OrbitCalculator().calculateStats(
            events: completionEvents,
            existingCompassionPasses: passes
        )
    }
    
    /// Featured daily sleep sound based on day of the year
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
        let sessions = (soundGroups[selectedKey] ?? []).sorted(by: { $0.duration < $1.duration })
        return (selectedKey, sessions)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                CosmosTheme.spaceBackground.ignoresSafeArea()
                
                // Subtle top background aura
                VStack {
                    LinearGradient(
                        colors: [CosmosTheme.cosmicIndigo.opacity(0.25), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 260)
                    .ignoresSafeArea()
                    Spacer()
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        // MARK: - App Bar Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("MindSpace")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: timeGreeting.icon)
                                        .font(.system(size: 11))
                                        .foregroundColor(CosmosTheme.starlightGold)
                                    Text(timeGreeting.greeting)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(CosmosTheme.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            NavigationLink(destination: SettingsView()) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(CosmosTheme.textSecondary)
                                        .frame(width: 42, height: 42)
                                        .background(CosmosTheme.spaceCard)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                                    
                                    if settingsList.first?.reminderEnabled == true {
                                        Circle()
                                            .fill(CosmosTheme.starlightGold)
                                            .frame(width: 9, height: 9)
                                            .offset(x: 2, y: -2)
                                    }
                                }
                            }
                            .buttonStyle(.cosmicPressable)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // MARK: - Unified Cosmic Orbit Hero Banner
                        if settingsList.first?.hideStreak != true {
                            cosmicOrbitHero
                                .padding(.horizontal, 20)
                        }
                        
                        // MARK: - Quick Intention Chips
                        quickIntentionsRow
                            .padding(.horizontal, 20)
                        
                        // MARK: - Daily Journey (3-item Micro-Path)
                        DailyJourneyView(
                            items: $dailyJourneyItems,
                            onSelectTrack: { track in
                                playbackEngine.loadAndPlay(track: track)
                                playbackEngine.isFullPlayerPresented = true
                            }
                        )
                        .padding(.horizontal, 20)
                        
                        // MARK: - Tonight's Featured Sleep Sound Sanctuary Card
                        if let sleepSound = dailySleepSound {
                            sleepSanctuaryCard(sleepSound)
                                .padding(.horizontal, 20)
                        }
                        
                        // MARK: - Continue Previous Session Card (if available)
                        if let lastResume = resumes.first {
                            continueSessionCard(lastResume)
                                .padding(.horizontal, 20)
                        }
                        
                        // MARK: - SOS Emergency Relief
                        sosReliefCard
                            .padding(.horizontal, 20)
                        
                        Spacer(minLength: 90)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupDynamicDailyJourney()
            }
            .onChange(of: completionEvents.count) { _, _ in
                setupDynamicDailyJourney()
            }
        }
    }
    
    // MARK: - Cosmic Orbit Hero Banner
    private var cosmicOrbitHero: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("ORBIT STREAK")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.moonLavender)
                        .tracking(1.0)
                    
                    if orbitStats.availableCompassionPasses > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 10))
                            Text("\(orbitStats.availableCompassionPasses) pass")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(CosmosTheme.starlightGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(CosmosTheme.starlightGold.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
                
                Text("\(max(1, orbitStats.currentStreak)) Days Mindful")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                Text(timeGreeting.prompt)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Mini Orbit Arc Gauge
            ZStack {
                Circle()
                    .stroke(CosmosTheme.spaceCardBorder, lineWidth: 10)
                    .frame(width: 78, height: 78)
                
                let progress = min(1.0, Double(max(1, orbitStats.currentStreak)) / Double(max(1, orbitStats.nextMilestoneDays)))
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        CosmosTheme.orbitGaugeGradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 78, height: 78)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(max(1, orbitStats.currentStreak))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                    Text("of \(orbitStats.nextMilestoneDays)d")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
            }
        }
        .cosmicHeroStyle(cornerRadius: 22, glowColor: CosmosTheme.cosmicPurple, padding: 18)
    }
    
    // MARK: - Quick Intentions Row
    private var quickIntentionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                quickIntentionPill("🌅 Awaken", color: CosmosTheme.starlightGold) {
                    playFirstAvailable(matching: "morning")
                }
                quickIntentionPill("⚡ 5-min Reset", color: CosmosTheme.auroraTeal) {
                    playFirstAvailable(matching: "reset")
                }
                quickIntentionPill("🌙 Sleep Sanctuary", color: CosmosTheme.moonLavender) {
                    if let sound = dailySleepSound, let first = sound.sessions.first {
                        playSleepSession(first, soundName: sound.soundName)
                    }
                }
                quickIntentionPill("🛡️ SOS Calm", color: CosmosTheme.solarCoral) {
                    startSOSQuickRelief()
                }
            }
        }
    }
    
    private func quickIntentionPill(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticService.shared.light()
            action()
        }) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(CosmosTheme.spaceCard)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.cosmicPressable)
    }
    
    // MARK: - Tonight's Sleep Sanctuary Card
    private func sleepSanctuaryCard(_ sleepSound: (soundName: String, sessions: [SingleSession])) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                CelestialPlanetView(style: .crescentMoon, size: 48, hasRings: false)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tonight's Sleep Sound")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.moonLavender)
                        .tracking(0.8)
                    
                    Text(sleepSound.soundName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                }
                
                Spacer()
                
                if let firstSession = sleepSound.sessions.first {
                    Button(action: {
                        HapticService.shared.medium()
                        playSleepSession(firstSession, soundName: sleepSound.soundName)
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 38))
                            .foregroundColor(CosmosTheme.moonLavender)
                    }
                    .buttonStyle(.cosmicPressable)
                }
            }
            
            // Duration Option Pills
            HStack(spacing: 8) {
                ForEach(sleepSound.sessions) { session in
                    Button(action: {
                        HapticService.shared.medium()
                        playSleepSession(session, soundName: sleepSound.soundName)
                    }) {
                        Text(session.formattedDuration)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(CosmosTheme.spacePill)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.cosmicPressable)
                }
            }
        }
        .cosmicCardStyle(cornerRadius: 20, borderColor: CosmosTheme.moonLavender.opacity(0.3), padding: 16)
    }
    
    // MARK: - Continue Last Session Card
    private func continueSessionCard(_ lastResume: PlaybackResume) -> some View {
        HStack(spacing: 14) {
            CelestialPlanetView(style: .purpleRinged, size: 46, hasRings: false)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("CONTINUE LISTENING")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.moonLavender)
                    .tracking(0.8)
                
                Text(lastResume.sessionTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                    .lineLimit(1)
                
                if let cName = lastResume.courseName {
                    Text(cName)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                HapticService.shared.medium()
                let track = PlayableTrack(
                    id: lastResume.sessionStableId,
                    title: lastResume.sessionTitle,
                    courseName: lastResume.courseName,
                    relativePath: lastResume.relativePath,
                    duration: lastResume.durationSeconds
                )
                playbackEngine.loadAndPlay(track: track, startPosition: lastResume.lastPositionSeconds)
                playbackEngine.isFullPlayerPresented = true
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(CosmosTheme.cosmicPurple)
            }
            .buttonStyle(.cosmicPressable)
        }
        .cosmicCardStyle(cornerRadius: 18, padding: 16)
    }
    
    // MARK: - SOS Emergency Relief Card
    private var sosReliefCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(CosmosTheme.solarCoral.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 22))
                    .foregroundColor(CosmosTheme.solarCoral)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Need Immediate Calm?")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                Text("3-minute SOS reset for sudden stress")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
            }
            
            Spacer()
            
            Button(action: {
                HapticService.shared.medium()
                startSOSQuickRelief()
            }) {
                Text("SOS")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(CosmosTheme.solarCoral)
                    .clipShape(Capsule())
                    .shadow(color: CosmosTheme.solarCoral.opacity(0.4), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.cosmicPressable)
        }
        .cosmicCardStyle(cornerRadius: 18, borderColor: CosmosTheme.solarCoral.opacity(0.3), padding: 16)
    }
    
    // MARK: - Helpers
    private func setupDynamicDailyJourney() {
        var items: [DailyJourneyItem] = []
        let allCourses = catalogService.manifest?.categories.flatMap { $0.courses } ?? []
        
        var activeCourse: CatalogCourse?
        var nextSessionToPlay: CatalogSession?
        
        if let latestResume = resumes.first,
           let matched = allCourses.first(where: { $0.name == latestResume.courseName || $0.folderName == latestResume.courseName || $0.sessions.contains(where: { $0.id == latestResume.sessionStableId }) }) {
            activeCourse = matched
            nextSessionToPlay = matched.sessions.first(where: { !completedSessionIDs.contains($0.id) }) ?? matched.sessions.first
        } else if let latestEvent = completionEvents.first(where: { $0.isQualifyingMeditation }),
                  let matched = allCourses.first(where: { c in c.sessions.contains(where: { $0.id == latestEvent.sessionStableId }) }) {
            activeCourse = matched
            nextSessionToPlay = matched.sessions.first(where: { !completedSessionIDs.contains($0.id) }) ?? matched.sessions.first
        }
        
        if activeCourse == nil {
            activeCourse = allCourses.first(where: { $0.name.contains("Basics") || $0.folderName.contains("Basics") }) ?? allCourses.first
            nextSessionToPlay = activeCourse?.sessions.first(where: { !completedSessionIDs.contains($0.id) }) ?? activeCourse?.sessions.first
        }
        
        if let course = activeCourse, let session = nextSessionToPlay {
            let track = PlayableTrack(
                id: session.id,
                title: session.title,
                courseName: course.name,
                relativePath: session.relativePath,
                duration: session.duration,
                videoAttachmentPath: session.videoAttachments?.first?.relativePath,
                dayNumber: session.dayNumber
            )
            let isDoneToday = completedSessionIDs.contains(session.id)
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
           let reset5Min = unwindCat.sessions.first(where: { $0.title.localizedCaseInsensitiveContains("reset") && ($0.title.contains("5") || ($0.duration >= 280 && $0.duration <= 320)) }) ?? unwindCat.sessions.first {
            let track = PlayableTrack(
                id: reset5Min.id,
                title: reset5Min.title,
                courseName: "Unwind",
                relativePath: reset5Min.relativePath,
                duration: reset5Min.duration
            )
            items.append(DailyJourneyItem(
                id: "journey_2",
                title: "5 min reset",
                durationLabel: "5 min",
                isPrimaryAction: false,
                isCompleted: false,
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
        
        if let nightSession = catalogService.manifest?.singlesCategories.first(where: { $0.name.contains("Good Night") || $0.name.contains("Sleep") })?.sessions.first {
            let track = PlayableTrack(
                id: nightSession.id,
                title: nightSession.title,
                courseName: "Sleep & Rest",
                relativePath: nightSession.relativePath,
                duration: nightSession.duration
            )
            items.append(DailyJourneyItem(
                id: "journey_3",
                title: "Evening wind-down",
                durationLabel: "\(max(1, Int(nightSession.duration / 60))) min",
                isPrimaryAction: false,
                isCompleted: false,
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
        
        dailyJourneyItems = items
    }
    
    private func playSleepSession(_ session: SingleSession, soundName: String) {
        let track = PlayableTrack(
            id: session.id,
            title: "\(soundName) (\(session.formattedDuration))",
            courseName: "Sleep Sounds",
            relativePath: session.relativePath,
            duration: session.duration
        )
        playbackEngine.loadAndPlay(track: track)
        playbackEngine.isFullPlayerPresented = true
    }
    
    private func playFirstAvailable(matching keyword: String) {
        let lower = keyword.lowercased()
        if let match = catalogService.manifest?.singlesCategories.flatMap({ $0.sessions }).first(where: { $0.title.lowercased().contains(lower) }) {
            let track = PlayableTrack(
                id: match.id,
                title: match.title,
                courseName: match.category,
                relativePath: match.relativePath,
                duration: match.duration
            )
            playbackEngine.loadAndPlay(track: track)
            playbackEngine.isFullPlayerPresented = true
        }
    }
    
    private func startSOSQuickRelief() {
        if let sosCat = catalogService.manifest?.singlesCategories.first(where: { $0.name == "SOS" }),
           let firstSOS = sosCat.sessions.first(where: { $0.title.localizedCaseInsensitiveContains("panic") || $0.title.localizedCaseInsensitiveContains("overwhelm") }) ?? sosCat.sessions.first {
            let track = PlayableTrack(
                id: firstSOS.id,
                title: firstSOS.title,
                courseName: "SOS Relief",
                relativePath: firstSOS.relativePath,
                duration: firstSOS.duration
            )
            playbackEngine.loadAndPlay(track: track)
            playbackEngine.isFullPlayerPresented = true
        }
    }
}
