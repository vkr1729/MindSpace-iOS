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
                                
                                Button(action: {}) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(CosmosTheme.textSecondary)
                                        
                                        Circle()
                                            .fill(CosmosTheme.starlightGold)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 2, y: -2)
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
                        OrbitArcGaugeView(
                            currentStreak: max(1, orbitStats.currentStreak),
                            milestoneGoal: orbitStats.nextMilestoneDays,
                            size: 180,
                            lineWidth: 16
                        )
                        .padding(.vertical, 8)
                        
                        // MARK: - Daily Journey (3-item Micro-Path)
                        DailyJourneyView(
                            items: $dailyJourneyItems,
                            onSelectTrack: { track in
                                playbackEngine.loadAndPlay(track: track)
                                playbackEngine.isFullPlayerPresented = true
                            }
                        )
                        .padding(.horizontal, 20)
                        
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
                setupDefaultDailyJourney()
            }
        }
    }
    
    private func setupDefaultDailyJourney() {
        guard dailyJourneyItems.isEmpty else { return }
        
        var items: [DailyJourneyItem] = []
        
        // Find Basics Day 4 or first available Basics session
        if let basicsCourse = catalogService.manifest?.categories.first?.courses.first,
           let basicsDay4 = basicsCourse.sessions.first(where: { $0.dayNumber == 4 }) ?? basicsCourse.sessions.first {
            let track = PlayableTrack(
                id: basicsDay4.id,
                title: basicsDay4.title,
                courseName: basicsCourse.name,
                relativePath: basicsDay4.relativePath,
                duration: basicsDay4.duration,
                videoAttachmentPath: basicsDay4.videoAttachments?.first?.relativePath,
                dayNumber: basicsDay4.dayNumber
            )
            items.append(DailyJourneyItem(
                id: "journey_1",
                title: "Continue \(basicsCourse.name) — Day \(basicsDay4.dayNumber)",
                durationLabel: "\(Int(basicsDay4.duration / 60)) min",
                isPrimaryAction: true,
                isCompleted: false,
                playableTrack: track
            ))
        } else {
            items.append(DailyJourneyItem(
                id: "journey_1",
                title: "Continue Basics — Day 4",
                durationLabel: "10 min",
                isPrimaryAction: true,
                isCompleted: false
            ))
        }
        
        // 5 min reset
        if let resetSession = catalogService.manifest?.singlesCategories.first(where: { $0.name.contains("Unwind") || $0.name.contains("SOS") })?.sessions.first {
            let track = PlayableTrack(
                id: resetSession.id,
                title: resetSession.title,
                courseName: "Quick Reset",
                relativePath: resetSession.relativePath,
                duration: resetSession.duration
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
        
        // Evening wind-down
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
                durationLabel: "10 min",
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
    
    private func startSOSQuickRelief() {
        if let sosCat = catalogService.manifest?.singlesCategories.first(where: { $0.name == "SOS" }),
           let firstSOS = sosCat.sessions.first {
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
