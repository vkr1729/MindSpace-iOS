import SwiftUI
import SwiftData

/// Screen 1: Today Screen (Canonical Blueprint)
/// Reference: Mock Screen Codex.png
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
    
    private var timeGreeting: (greeting: String, prompt: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return ("Good morning", "Start your day with presence.")
        } else if hour < 17 {
            return ("Good afternoon", "Pause and center yourself.")
        } else {
            return ("Good evening", "Take a breath. You're here.")
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
        
        // Group sessions by subfolder/sound name (e.g. Dream, Drift Off, Doze, Slumber, Power Down, Snooze)
        var soundGroups: [String: [SingleSession]] = [:]
        for session in sleepCat.sessions {
            // Extract base sound name from title, e.g. "Sound - Dream - 10min" -> "Dream"
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Header & Time Greeting
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("MindSpace")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                
                                Spacer()
                                
                                NavigationLink(destination: SettingsView()) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(CosmosTheme.textSecondary)
                                        
                                        if settingsList.first?.reminderEnabled == true {
                                            Circle()
                                                .fill(CosmosTheme.starlightGold)
                                                .frame(width: 8, height: 8)
                                                .offset(x: 2, y: -2)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(timeGreeting.greeting)
                                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                
                                Text(timeGreeting.prompt)
                                    .font(.system(size: 15, weight: .regular, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // MARK: - Orbit Streak Gauge
                        if settingsList.first?.hideStreak != true {
                            OrbitArcGaugeView(
                                currentStreak: max(1, orbitStats.currentStreak),
                                milestoneGoal: orbitStats.nextMilestoneDays,
                                size: 180,
                                lineWidth: 16
                            )
                            .padding(.vertical, 8)
                        }
                        
                        // MARK: - Daily Journey (3-item Micro-Path)
                        DailyJourneyView(
                            items: $dailyJourneyItems,
                            onSelectTrack: { track in
                                playbackEngine.loadAndPlay(track: track)
                                playbackEngine.isFullPlayerPresented = true
                            }
                        )
                        .padding(.horizontal, 20)
                        
                        // MARK: - Tonight's Featured Sleep Sound
                        if let sleepSound = dailySleepSound {
                            CosmicCard(padding: 16) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        CelestialPlanetView(style: .crescentMoon, size: 44, hasRings: false)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Tonight's Sleep Sound")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundColor(CosmosTheme.moonLavender)
                                                .textCase(.uppercase)
                                            
                                            Text(sleepSound.soundName)
                                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                                .foregroundColor(CosmosTheme.textPrimary)
                                        }
                                        
                                        Spacer()
                                        
                                        if let firstSession = sleepSound.sessions.first {
                                            Button(action: {
                                                playSleepSession(firstSession, soundName: sleepSound.soundName)
                                            }) {
                                                Image(systemName: "play.circle.fill")
                                                    .font(.system(size: 36))
                                                    .foregroundColor(CosmosTheme.moonLavender)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    
                                    // Duration Option Pills
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(sleepSound.sessions) { session in
                                                Button(action: {
                                                    playSleepSession(session, soundName: sleepSound.soundName)
                                                }) {
                                                    Text(session.formattedDuration)
                                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                                        .foregroundColor(CosmosTheme.textPrimary)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(CosmosTheme.spacePill)
                                                        .clipShape(Capsule())
                                                        .overlay(
                                                            Capsule().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // MARK: - Continue Previous Session Card (if available)
                        if let lastResume = resumes.first {
                            CosmicCard(padding: 16) {
                                HStack(spacing: 16) {
                                    CelestialPlanetView(style: .purpleRinged, size: 50, hasRings: false)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Continue Listening")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundColor(CosmosTheme.moonLavender)
                                            .textCase(.uppercase)
                                        
                                        Text(lastResume.sessionTitle)
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(CosmosTheme.textPrimary)
                                        
                                        if let cName = lastResume.courseName {
                                            Text(cName)
                                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                                .foregroundColor(CosmosTheme.textSecondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
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
                                            .font(.system(size: 38))
                                            .foregroundColor(CosmosTheme.cosmicPurple)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // MARK: - SOS Quick Relief
                        CosmicCard(padding: 16) {
                            HStack(spacing: 14) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.system(size: 28))
                                    .foregroundColor(CosmosTheme.solarCoral)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Need Immediate Calm?")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                    
                                    Text("3-minute SOS reset for sudden stress")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundColor(CosmosTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    startSOSQuickRelief()
                                }) {
                                    Text("SOS")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(CosmosTheme.solarCoral)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 80)
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
    
    private func setupDynamicDailyJourney() {
        var items: [DailyJourneyItem] = []
        let allCourses = catalogService.manifest?.categories.flatMap { $0.courses } ?? []
        
        // Find in-progress courses by checking completion events and resumes
        var activeCourse: CatalogCourse?
        var nextSessionToPlay: CatalogSession?
        
        // 1. Check most recent resume or completion event
        if let latestResume = resumes.first,
           let matched = allCourses.first(where: { $0.name == latestResume.courseName || $0.id == latestResume.courseId }) {
            activeCourse = matched
            nextSessionToPlay = matched.sessions.first(where: { !completedSessionIDs.contains($0.id) }) ?? matched.sessions.first
        } else if let latestEvent = completionEvents.first(where: { $0.isQualifyingMeditation }),
                  let matched = allCourses.first(where: { c in c.sessions.contains(where: { $0.id == latestEvent.sessionStableId }) }) {
            activeCourse = matched
            nextSessionToPlay = matched.sessions.first(where: { !completedSessionIDs.contains($0.id) }) ?? matched.sessions.first
        }
        
        // 2. Fallback to Basics course if no course in progress yet
        if activeCourse == nil {
            activeCourse = allCourses.first(where: { $0.name.contains("Basics") || $0.folderName.contains("Basics") }) ?? allCourses.first
            nextSessionToPlay = activeCourse?.sessions.first(where: { !completedSessionIDs.contains($0.id) }) ?? activeCourse?.sessions.first
        }
        
        // Item 1: In-Progress Course Session
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
        
        // Item 2: 5 Min Reset (Specifically from Unwind -> Reset 5min)
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
        
        // Item 3: Evening wind-down
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
