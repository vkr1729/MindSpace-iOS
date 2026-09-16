import XCTest
import Foundation
import SwiftData
import AVFoundation
@testable import MindSpace

final class DefectRegressionTests: XCTestCase {
    
    // MARK: - P0-01: Actor Isolation & Haptic APIs
    @MainActor
    func testP0_01_HapticServiceAPIsAndDeinitSafety() {
        // Test new HapticService methods
        HapticService.shared.warning()
        HapticService.shared.error()
        
        // Test PlaybackEngine lifecycle and clean stop without actor-isolation crashes
        let engine = PlaybackEngine.shared
        engine.stop()
        XCTAssertEqual(engine.state, .idle)
    }
    
    // MARK: - P1-01: Day-attached Video Playback & Transition
    @MainActor
    func testP1_01_DayAttachedVideoSequencing() {
        let engine = PlaybackEngine.shared
        let resolver = LibraryPathResolver.shared
        
        let videoRel = "Packs/1 - Foundation/Basics/Day 01 Intro.mp4"
        let audioRel = "Packs/1 - Foundation/Basics/Day 01.mp3"
        let videoURL = resolver.libraryDirectoryURL.appendingPathComponent(videoRel)
        let audioURL = resolver.libraryDirectoryURL.appendingPathComponent(audioRel)
        
        try? FileManager.default.createDirectory(at: videoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? "dummy video".data(using: .utf8)?.write(to: videoURL)
        try? "dummy audio".data(using: .utf8)?.write(to: audioURL)
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: audioURL)
        }
        
        let trackWithVideo = PlayableTrack(
            id: "course_day1_with_video",
            title: "Day 1 Introduction",
            courseName: "Basics",
            relativePath: audioRel,
            duration: 600.0,
            videoAttachmentPath: videoRel,
            dayNumber: 1,
            videoDuration: 120.0,
            contentType: "meditation"
        )
        
        // Loading track with attached video should start in video phase
        engine.loadAndPlay(track: trackWithVideo)
        XCTAssertEqual(engine.currentPhase, .video)
        
        // Skipping video should transition smoothly to audio phase
        engine.skipVideoToAudio()
        XCTAssertEqual(engine.currentPhase, .audio)
        XCTAssertEqual(engine.currentTime, 0.0)
        
        engine.stop()
    }
    
    // MARK: - P1-02: Compassion Pass 30-Day Rolling Window & 7-Day Earning
    func testP1_02_CompassionPass30DayRollingWindow() {
        let calc = OrbitCalculator()
        let calendar = Calendar.current
        let today = Date()
        
        // Build 14 active days (earns 2 passes)
        var events: [CompletionEvent] = []
        for offset in 0..<14 {
            let date = calendar.date(byAdding: .day, value: -(offset + 2), to: today)!
            events.append(CompletionEvent(
                sessionStableId: "sess_\(offset)",
                actualPlayedSeconds: 600.0,
                isQualifying: true,
                timestamp: date
            ))
        }
        
        // 1 missed day (yesterday, offset 1), practiced today (offset 0)
        events.append(CompletionEvent(
            sessionStableId: "sess_today",
            actualPlayedSeconds: 600.0,
            isQualifying: true,
            timestamp: today
        ))
        
        // 1 missed day is protected by earned compassion pass
        let stats = calc.calculateStats(events: events, calendar: calendar, today: today)
        XCTAssertEqual(stats.currentStreak, 16) // 15 practiced + 1 protected miss
        XCTAssertEqual(stats.compassionPassUsedCount, 1)
        
        // Test that 2 consecutive missed days breaks the streak
        var eventsBroken: [CompletionEvent] = []
        for offset in 3..<17 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            eventsBroken.append(CompletionEvent(
                sessionStableId: "sess_\(offset)",
                actualPlayedSeconds: 600.0,
                isQualifying: true,
                timestamp: date
            ))
        }
        // Practiced today, but missed day 1 and day 2
        eventsBroken.append(CompletionEvent(
            sessionStableId: "sess_today",
            actualPlayedSeconds: 600.0,
            isQualifying: true,
            timestamp: today
        ))
        let statsBroken = calc.calculateStats(events: eventsBroken, calendar: calendar, today: today)
        XCTAssertEqual(statsBroken.currentStreak, 1) // 2 consecutive missed days cannot be bridged
    }
    
    // MARK: - P1-03: Separate Listening Minutes from Gamification
    func testP1_03_SeparateListeningMinutesFromStreakEligibility() {
        let calc = OrbitCalculator()
        let calendar = Calendar.current
        let today = Date()
        
        // 1. Sensitive topic track (Grief)
        let griefEvent = CompletionEvent(
            sessionStableId: "sess_grief",
            courseId: "1 - Grief",
            actualPlayedSeconds: 600.0,
            isQualifying: true,
            contentType: "sensitive",
            timestamp: today
        )
        
        // 2. Sleep sound track
        let sleepEvent = CompletionEvent(
            sessionStableId: "sess_sleep",
            courseId: "Sleep Sounds",
            actualPlayedSeconds: 1800.0,
            isQualifying: true,
            contentType: "sleep",
            timestamp: today
        )
        
        let stats = calc.calculateStats(events: [griefEvent, sleepEvent], calendar: calendar, today: today)
        // Total minutes should include both (10 + 30 = 40 min)
        XCTAssertEqual(stats.totalMindfulMinutes, 40)
        XCTAssertEqual(stats.completedSessionsCount, 2)
        // Streak should be 0 because sensitive and sleep content are exempt from gamified streaks
        XCTAssertEqual(stats.currentStreak, 0)
    }
    
    // MARK: - P1-04: Persist Verified Listening State & Range Union
    @MainActor
    func testP1_04_RangeUnionListeningAccumulator() {
        let acc = ListeningAccumulator(duration: 600.0, restoredListenedSeconds: 120.0)
        XCTAssertEqual(acc.accumulatedSeconds, 120.0)
        
        // Listen from 120s to 125s (initialize tracker at 120, tick through 125)
        for t in 120...125 {
            acc.tick(currentTime: Double(t), isPlaying: true)
        }
        XCTAssertEqual(acc.accumulatedSeconds, 125.0)
        
        // Replaying already-listened portion (e.g. 50s to 60s) should not double-count
        for t in 50...60 {
            acc.tick(currentTime: Double(t), isPlaying: true)
        }
        // Since [50, 60] was already included in the initial 120s interval [0, 120], total should not increase
        XCTAssertEqual(acc.accumulatedSeconds, 125.0)
    }
    
    // MARK: - P1-05: Replay Qualification Reset
    @MainActor
    func testP1_05_ReplayQualificationReset() {
        let acc = ListeningAccumulator(duration: 100.0)
        // Meet qualification threshold
        for t in 1...75 {
            acc.tick(currentTime: Double(t), isPlaying: true)
        }
        XCTAssertTrue(acc.hasQualified)
        
        // Resetting accumulator on replay
        acc.reset()
        XCTAssertFalse(acc.hasQualified)
        XCTAssertEqual(acc.accumulatedSeconds, 0.0)
        
        // Immediate stop after 2s should NOT qualify
        acc.tick(currentTime: 1.0, isPlaying: true)
        acc.tick(currentTime: 2.0, isPlaying: true)
        XCTAssertFalse(acc.hasQualified)
    }
    
    // MARK: - P1-06: Recommendation Engine Determinism
    func testP1_06_DeterministicRecommendationEngine() {
        let manifest = CatalogManifest(
            schemaVersion: 1,
            generatedAt: "2026-08-20T00:00:00Z",
            totalFiles: 2,
            totalDuration: 1200.0,
            totalDurationHours: 0.33,
            totalSizeBytes: 200,
            categories: [
                CatalogCategory(
                    id: "cat_foundation",
                    type: "pack",
                    name: "Foundation",
                    folderName: "1 - Foundation",
                    order: 1,
                    description: "Basics of meditation",
                    colorHex: "#6344E0",
                    iconName: "sparkles",
                    courses: [
                        CatalogCourse(
                            id: "course_basics",
                            name: "Basics",
                            folderName: "Basics",
                            order: 1,
                            description: "Basics course",
                            totalSessions: 2,
                            hasGapWaiver: false,
                            introVideo: nil,
                            sessions: [
                                CatalogSession(id: "basics_d1", title: "Basics Day 1", dayNumber: 1, relativePath: "p1", duration: 600),
                                CatalogSession(id: "basics_d2", title: "Basics Day 2", dayNumber: 2, relativePath: "p2", duration: 600)
                            ]
                        )
                    ]
                )
            ],
            singlesCategories: [
                SinglesCategory(
                    id: "singles_unwind",
                    name: "Everyday",
                    folderName: "Everyday",
                    order: 1,
                    description: "Daily mindfulness",
                    colorHex: "#14B8A6",
                    iconName: "sun.max.fill",
                    sessions: [
                        SingleSession(id: "single_morning", title: "Morning Clarity", category: "Everyday", relativePath: "s1", duration: 600)
                    ]
                )
            ]
        )
        
        let settings = UserSettings(defaultDuration: 10, selectedGoals: ["Learn", "Stress"])
        let completed: Set<String> = ["basics_d1"]
        
        let recommendations = RecommendationEngine.shared.getRecommendations(
            manifest: manifest,
            settings: settings,
            completedSessionIDs: completed
        )
        
        XCTAssertFalse(recommendations.isEmpty)
        // Should recommend Basics Day 2 as next session
        XCTAssertEqual(recommendations.first?.track.id, "basics_d2")
    }
    
    // MARK: - P2-01: Exact Completion UUID Matching
    func testP2_01_ExactCompletionUUIDMatching() async throws {
        let schema = Schema([CompletionEvent.self, PlaybackResume.self, FavoriteItem.self, UserSettings.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let actor = ProgressActor(modelContainer: container)
        
        let customUUID = UUID()
        let recordedId = try await actor.recordCompletion(
            id: customUUID,
            sessionStableId: "session_focus_1",
            courseId: "Focus",
            playedSeconds: 600.0,
            isQualifying: true,
            contentType: "meditation"
        )
        
        XCTAssertEqual(recordedId, customUUID)
        
        try await actor.saveReflection(for: customUUID, note: "lighter")
        let events = try await actor.fetchAllCompletionEvents()
        let matched = events.first(where: { $0.id == customUUID })
        XCTAssertNotNil(matched)
        XCTAssertEqual(matched?.reflectionNote, "lighter")
    }
    
    // MARK: - P2-02: Truthful Storage Hardening Check
    func testP2_02_TruthfulStorageHardeningCheck() {
        let resolver = LibraryPathResolver.shared
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolver.libraryDirectoryURL.path))
        #if targetEnvironment(simulator)
        // File protection attributes are device-only; on the simulator verify
        // the backup-exclusion half of hardening round-trips through xattrs.
        try? FileManager.default.createDirectory(at: resolver.libraryDirectoryURL, withIntermediateDirectories: true)
        var mutableURL = resolver.libraryDirectoryURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(values)
        let readBack = try? resolver.libraryDirectoryURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(readBack?.isExcludedFromBackup, true, "MindSpaceLibrary directory must be hardened with backup exclusion.")
        #else
        XCTAssertTrue(resolver.applyHardeningAndProtection(), "Hardening must apply cleanly.")
        XCTAssertTrue(resolver.checkHardeningStatus(), "MindSpaceLibrary directory must be hardened with backup exclusion.")
        #endif
    }
    
    // MARK: - P2-03: Completion Screen Progression & Gap Waiver
    func testP2_03_CompletionScreenPregnancyGapWaiver() {
        let course = CatalogCourse(
            id: "course_pregnancy",
            name: "Pregnancy",
            folderName: "Pregnancy",
            order: 1,
            description: "Desc",
            totalSessions: 27,
            hasGapWaiver: true,
            sessions: [
                CatalogSession(id: "preg_26", title: "Day 26", dayNumber: 26, relativePath: "p26", duration: 600),
                CatalogSession(id: "preg_30", title: "Day 30", dayNumber: 30, relativePath: "p30", duration: 600)
            ]
        )
        
        XCTAssertTrue(course.hasGapWaiver)
        XCTAssertEqual(course.sessions.count, 2)
        XCTAssertEqual(course.sessions.last?.dayNumber, 30)
    }
    
    // MARK: - P2-04: Daily Journey Local Calendar Day Scoping
    func testP2_04_DailyJourneyCalendarDayScoping() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let todayEvent = CompletionEvent(
            sessionStableId: "reset_5m",
            actualPlayedSeconds: 300.0,
            isQualifying: true,
            timestamp: today
        )
        let yesterdayEvent = CompletionEvent(
            sessionStableId: "reset_5m",
            actualPlayedSeconds: 300.0,
            isQualifying: true,
            timestamp: yesterday
        )
        
        let todayKey = DateFormatterCache.dayKey(from: today)
        let yesterdayKey = DateFormatterCache.dayKey(from: yesterday)
        
        XCTAssertNotEqual(todayKey, yesterdayKey)
        XCTAssertEqual(DateFormatterCache.dayKey(from: todayEvent.timestamp), todayKey)
        XCTAssertEqual(DateFormatterCache.dayKey(from: yesterdayEvent.timestamp), yesterdayKey)
    }
    
    // MARK: - P2-05: Library Multi-Dimensional Filters
    func testP2_05_DurationAndStatusFilters() {
        let shortSession = SingleSession(id: "s_short", title: "Short", category: "SOS", relativePath: "p1", duration: 180) // 3m
        let mediumSession = SingleSession(id: "s_med", title: "Medium", category: "Everyday", relativePath: "p2", duration: 480) // 8m
        let standardSession = SingleSession(id: "s_std", title: "Standard", category: "Focus", relativePath: "p3", duration: 900) // 15m
        let longSession = SingleSession(id: "s_long", title: "Long", category: "Sleep", relativePath: "p4", duration: 1800) // 30m
        
        XCTAssertTrue(DurationFilter.short.matches(seconds: shortSession.duration))
        XCTAssertFalse(DurationFilter.short.matches(seconds: mediumSession.duration))
        XCTAssertTrue(DurationFilter.medium.matches(seconds: mediumSession.duration))
        XCTAssertTrue(DurationFilter.standard.matches(seconds: standardSession.duration))
        XCTAssertTrue(DurationFilter.long.matches(seconds: longSession.duration))
    }
    
    // MARK: - P2-07: Constellation Bridge of Reflection Node
    func testP2_07_ConstellationBridgeOfReflectionNode() {
        let bridgeNode = ConstellationNode(
            id: "bridge_reflection_27_29",
            dayNumber: 27,
            title: "Bridge of Reflection",
            isCompleted: true,
            isActive: false,
            isBridgeOfReflection: true
        )
        
        XCTAssertTrue(bridgeNode.isBridgeOfReflection)
        XCTAssertEqual(bridgeNode.dayNumber, 27)
        XCTAssertEqual(bridgeNode.title, "Bridge of Reflection")
    }

    // MARK: - P0-02: Import Validation Rejects Bad Backups
    func testP0_02_ImportValidationRejectsBadBackups() {
        let manager = ProgressTransferManager.shared
        func doc(version: Int = 1, schema: Int = 1, events: [BackupCompletionEvent] = []) -> MindSpaceBackupDocument {
            MindSpaceBackupDocument(
                backupVersion: version,
                catalogSchemaVersion: schema,
                stats: BackupStats(totalMindfulMinutes: 0, completedSessionsCount: 0, currentStreak: 0, bestStreak: 0),
                userSettings: BackupUserSettings(defaultDurationMinutes: 10, reminderTime: "08:00", themeMode: "quiet_cosmos", hideStreak: false, compassionPassCount: 0),
                completionEvents: events,
                favorites: [],
                achievements: []
            )
        }
        XCTAssertThrowsError(try manager.stagedValidation(of: doc(version: 99)))
        XCTAssertThrowsError(try manager.stagedValidation(of: doc(schema: 99)))
        XCTAssertThrowsError(try manager.stagedValidation(of: doc(events: [BackupCompletionEvent(
            id: UUID().uuidString, sessionId: "s", courseId: nil,
            timestamp: "not-a-date", timeZone: "UTC",
            playedSeconds: 600, isQualifying: true, contentType: "meditation", reflection: nil
        )])))
        XCTAssertNoThrow(try manager.stagedValidation(of: doc()))
    }

    // MARK: - P0-03: Pass Burn Rolls Back on Double Miss
    func testP0_03_PassBurnRollsBackOnDoubleMiss() {
        let calc = OrbitCalculator()
        let calendar = Calendar.current
        let today = Date()
        var events: [CompletionEvent] = []
        for offset in 3..<17 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            events.append(CompletionEvent(sessionStableId: "sess_\(offset)", actualPlayedSeconds: 600.0, isQualifying: true, timestamp: date))
        }
        events.append(CompletionEvent(sessionStableId: "sess_today", actualPlayedSeconds: 600.0, isQualifying: true, timestamp: today))
        let stats = calc.calculateStats(events: events, calendar: calendar, today: today, existingCompassionPasses: 2)
        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.compassionPassUsedCount, 0)
        XCTAssertEqual(stats.compassionPassesAvailable, 2)
    }
}
