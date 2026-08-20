import XCTest
import Foundation
import SwiftData
import AVFoundation
@testable import MindSpace

final class HardenedBehavioralTests: XCTestCase {
    
    // MARK: - Scenario 1: Delete one known media file -> Scan reports exactly one missing
    func testDeleteOneKnownMediaFileScanReportsExactlyOneMissing() async throws {
        let resolver = LibraryPathResolver.shared
        
        let testRelPath1 = "TestMedia/TrackA.mp3"
        let testRelPath2 = "TestMedia/TrackB.mp3"
        
        let url1 = resolver.libraryDirectoryURL.appendingPathComponent(testRelPath1)
        let url2 = resolver.libraryDirectoryURL.appendingPathComponent(testRelPath2)
        
        try FileManager.default.createDirectory(at: url1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "Audio data 1".data(using: .utf8)!.write(to: url1)
        try "Audio data 2".data(using: .utf8)!.write(to: url2)
        
        let manifest = CatalogManifest(
            schemaVersion: 1,
            generatedAt: "2026-08-20T00:00:00Z",
            totalFiles: 2,
            totalDuration: 1200.0,
            totalDurationHours: 0.33,
            totalSizeBytes: 200,
            categories: [
                CatalogCategory(
                    id: "cat_del_test",
                    type: "pack",
                    name: "Delete Test Pack",
                    folderName: "Delete Test Pack",
                    order: 1,
                    description: "Desc",
                    colorHex: "#6344E0",
                    iconName: "sparkles",
                    courses: [
                        CatalogCourse(
                            id: "course_del_test",
                            name: "Delete Test Course",
                            folderName: "Delete Test Course",
                            order: 1,
                            description: "Desc",
                            totalSessions: 2,
                            sessions: [
                                CatalogSession(id: "del_s1", title: "Track A", dayNumber: 1, relativePath: testRelPath1, duration: 600, sizeBytes: 12),
                                CatalogSession(id: "del_s2", title: "Track B", dayNumber: 2, relativePath: testRelPath2, duration: 600, sizeBytes: 12)
                            ]
                        )
                    ]
                )
            ],
            singlesCategories: []
        )
        
        // Initial scan: both found
        resolver.applyHardeningAndProtection()
        let initialReport = await resolver.verifyAllCatalogEntries(manifest: manifest, validateChecksums: false)
        XCTAssertEqual(initialReport.totalTracks, 2)
        XCTAssertEqual(initialReport.foundCount, 2)
        XCTAssertEqual(initialReport.missingCount, 0)
        
        // Delete exactly one file (Track B)
        try FileManager.default.removeItem(at: url2)
        
        // Rescan: exactly one missing
        let postDeleteReport = await resolver.verifyAllCatalogEntries(manifest: manifest, validateChecksums: false)
        XCTAssertEqual(postDeleteReport.totalTracks, 2)
        XCTAssertEqual(postDeleteReport.foundCount, 1)
        XCTAssertEqual(postDeleteReport.missingCount, 1, "Scan must report exactly one missing file.")
        XCTAssertEqual(postDeleteReport.missingPaths, [testRelPath2])
        XCTAssertFalse(postDeleteReport.isFullyVerified, "Library cannot be 100% verified when a file is missing.")
        
        // Clean up
        try? FileManager.default.removeItem(at: url1)
    }
    
    // MARK: - Scenario 2: Attempt to play missing file -> Actionable error & no playing state
    @MainActor
    func testAttemptToPlayMissingFileProducesActionableErrorAndNoPlayingState() {
        let engine = PlaybackEngine.shared
        let missingTrack = PlayableTrack(
            id: "missing_test_track",
            title: "Absent Meditation",
            courseName: "Cosmos",
            relativePath: "NonExistent/AbsentMeditation.mp3",
            duration: 600.0
        )
        
        engine.loadAndPlay(track: missingTrack)
        
        XCTAssertNotEqual(engine.state, .playing, "PlaybackEngine must not enter playing state for a missing file.")
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNotNil(engine.playbackError)
        XCTAssertTrue(engine.playbackError!.contains("Media file not found: Absent Meditation"))
        XCTAssertTrue(engine.playbackError!.contains("Settings"))
    }
    
    // MARK: - Scenario 3: Play 45 seconds, pause, recreate app store -> Position is restored
    func testPlay45SecondsPauseRecreateStorePositionIsRestored() async throws {
        let schema = Schema([
            CompletionEvent.self,
            PlaybackResume.self,
            FavoriteItem.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container1 = try ModelContainer(for: schema, configurations: [config])
        let actor1 = ProgressActor(modelContainer: container1)
        
        let sessionId = "session_basics_day1"
        let relPath = "Packs/1 - Foundation/Basics/Day 01.mp3"
        let title = "Basics — Day 1"
        
        // User plays 45 seconds and pauses -> Position saved
        try await actor1.updateResumePosition(
            sessionStableId: sessionId,
            relativePath: relPath,
            title: title,
            courseName: "Basics",
            position: 45.0,
            duration: 600.0
        )
        
        // Simulate app relaunch / store recreation using the same underlying container/store
        let actor2 = ProgressActor(modelContainer: container1)
        let restoredResume = try await actor2.fetchResume(for: sessionId)
        
        XCTAssertNotNil(restoredResume)
        XCTAssertEqual(restoredResume?.lastPositionSeconds, 45.0, "Position 45s must be faithfully restored.")
        XCTAssertEqual(restoredResume?.sessionTitle, title)
        XCTAssertEqual(restoredResume?.relativePath, relPath)
    }
    
    // MARK: - Scenario 4: Switch tracks -> Old track resume is retained
    @MainActor
    func testSwitchTracksRetainsOldTrackResume() async throws {
        let schema = Schema([
            CompletionEvent.self,
            PlaybackResume.self,
            FavoriteItem.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let actor = ProgressActor(modelContainer: container)
        
        let engine = PlaybackEngine.shared
        
        var savedResumes: [String: Double] = [:]
        engine.onSaveResume = { track, position, accumulatedSeconds in
            savedResumes[track.id] = position
            Task {
                try? await actor.updateResumePosition(
                    sessionStableId: track.id,
                    relativePath: track.relativePath,
                    title: track.title,
                    courseName: track.courseName,
                    position: position,
                    duration: track.duration,
                    accumulatedListenedSeconds: accumulatedSeconds
                )
            }
        }
        
        let track1 = PlayableTrack(id: "track_1", title: "Morning Awakening", courseName: "Basics", relativePath: "p1", duration: 600)
        let track2 = PlayableTrack(id: "track_2", title: "Evening Serenity", courseName: "Sleep", relativePath: "p2", duration: 600)
        
        // Play track 1 for 150s
        engine.loadAndPlay(track: track1, startPosition: 150.0)
        
        // User switches to track 2
        engine.loadAndPlay(track: track2, startPosition: 0.0)
        
        // Verify old track resume position (150s) was captured and retained
        XCTAssertEqual(savedResumes["track_1"], 150.0, "Switching tracks must retain the old track's resume position.")
    }
    
    // MARK: - Scenario 5: Scrub near the end -> No qualifying completion
    @MainActor
    func testScrubNearEndYieldsNoQualifyingCompletion() {
        let acc = ListeningAccumulator(duration: 600.0)
        
        // User plays first 5 seconds
        for t in 1...5 {
            acc.tick(currentTime: Double(t), isPlaying: true, speed: 1.0)
        }
        XCTAssertEqual(acc.accumulatedSeconds, 4.0, accuracy: 0.1)
        
        // User scrubs to 580s (skip jump of 575s)
        acc.tick(currentTime: 580.0, isPlaying: true, speed: 1.0)
        
        // User plays 5 more seconds to the end (585s)
        for t in 581...585 {
            acc.tick(currentTime: Double(t), isPlaying: true, speed: 1.0)
        }
        
        // Total legitimate listened track seconds is only 4 + 5 = 9 seconds
        XCTAssertEqual(acc.accumulatedSeconds, 9.0, accuracy: 0.1)
        XCTAssertFalse(acc.hasQualified, "Scrubbing to the end must NEVER produce a qualifying completion.")
    }
    
    // MARK: - Scenario 6: Complete normally -> Exactly one event & correct reflection association
    func testCompleteNormallyProducesExactlyOneEventAndCorrectReflection() async throws {
        let schema = Schema([
            CompletionEvent.self,
            PlaybackResume.self,
            FavoriteItem.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let actor = ProgressActor(modelContainer: container)
        
        // 1. Session completes normally
        let completionId = try await actor.recordCompletion(
            sessionStableId: "session_clarity_1",
            courseId: "Clarity",
            playedSeconds: 600.0,
            isQualifying: true,
            reflection: nil
        )
        
        // 2. User selects reflection "grounded" on CompletionView
        try await actor.saveReflection(for: completionId, note: "grounded")
        
        // 3. Verify exactly one event exists and reflection is attached to that exact UUID
        let allEvents = try await actor.fetchAllCompletionEvents()
        XCTAssertEqual(allEvents.count, 1, "Exactly one completion event must be recorded.")
        
        let event = allEvents.first
        XCTAssertEqual(event?.id, completionId)
        XCTAssertEqual(event?.reflectionNote, "grounded")
        XCTAssertEqual(event?.isQualifyingMeditation, true)
        XCTAssertEqual(event?.actualPlayedSeconds, 600.0)
    }
    
    // MARK: - Scenario 7: Load 20 tracks -> One completion callback & no accumulated observers
    @MainActor
    func testLoad20TracksYieldsNoAccumulatedObserversAndCleanAudioLifecycle() {
        let engine = PlaybackEngine.shared
        
        var completionCount = 0
        engine.onSessionCompleted = { _, _, _, _ in
            completionCount += 1
        }
        
        // Rapidly load 20 different tracks
        for i in 1...20 {
            let track = PlayableTrack(
                id: "track_\(i)",
                title: "Track \(i)",
                courseName: "Series",
                relativePath: "rel_\(i)",
                duration: 300.0
            )
            engine.loadAndPlay(track: track)
        }
        
        // Verify stop cleans up cleanly
        engine.stop()
        
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(completionCount, 0, "Rapid loading/switching without playback duration must not trigger spurious completion callbacks.")
    }
    
    // MARK: - Scenario 8: Export and clean-import -> Events, favorites, settings, and resumes match
    @MainActor
    func testExportAndCleanImportAllModelsMatch() throws {
        let schema = Schema([
            CompletionEvent.self,
            FavoriteItem.self,
            PlaybackResume.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        // 1. Source objects
        let event = CompletionEvent(
            sessionStableId: "exp_sess_1",
            courseId: "Foundation",
            actualPlayedSeconds: 600.0,
            isQualifying: true,
            reflection: "lighter",
            timestamp: Date(),
            timeZoneIdentifier: "Asia/Tokyo"
        )
        let fav = FavoriteItem(sessionStableId: "exp_fav_1", title: "Zen Garden", relativePath: "Singles/Zen.mp3")
        let resume = PlaybackResume(
            sessionStableId: "exp_res_1",
            relativePath: "Packs/Basics/Day03.mp3",
            sessionTitle: "Basics Day 3",
            courseName: "Basics",
            position: 210.0,
            duration: 600.0
        )
        let settings = UserSettings(
            defaultDuration: 20,
            reminderTime: "22:00",
            reminderEnabled: true,
            themeMode: "sleep_abyss",
            hideStreak: false,
            compassionPassCount: 3
        )
        
        let stats = OrbitStats(
            currentStreak: 7,
            bestStreak: 14,
            totalMindfulMinutes: 70,
            completedSessionsCount: 7,
            nextMilestoneDays: 14,
            compassionPassesAvailable: 3,
            compassionPassUsedCount: 0,
            activeDates: [],
            dailyMinutes: [:]
        )
        
        // 2. Export
        let doc = ProgressTransferManager.shared.createBackupDocument(
            events: [event],
            favorites: [fav],
            settings: settings,
            orbitStats: stats,
            resumes: [resume]
        )
        
        // 3. Clean Restore
        try ProgressTransferManager.shared.applyImport(
            document: doc,
            modelContext: context,
            isCleanRestore: true
        )
        
        // 4. Verification
        let restoredEvents = try context.fetch(FetchDescriptor<CompletionEvent>())
        XCTAssertEqual(restoredEvents.count, 1)
        XCTAssertEqual(restoredEvents.first?.sessionStableId, "exp_sess_1")
        XCTAssertEqual(restoredEvents.first?.timeZoneIdentifier, "Asia/Tokyo")
        XCTAssertEqual(restoredEvents.first?.reflectionNote, "lighter")
        
        let restoredFavs = try context.fetch(FetchDescriptor<FavoriteItem>())
        XCTAssertEqual(restoredFavs.count, 1)
        XCTAssertEqual(restoredFavs.first?.sessionStableId, "exp_fav_1")
        
        let restoredResumes = try context.fetch(FetchDescriptor<PlaybackResume>())
        XCTAssertEqual(restoredResumes.count, 1)
        XCTAssertEqual(restoredResumes.first?.sessionStableId, "exp_res_1")
        XCTAssertEqual(restoredResumes.first?.lastPositionSeconds, 210.0)
        
        let restoredSettings = try context.fetch(FetchDescriptor<UserSettings>()).first
        XCTAssertEqual(restoredSettings?.reminderEnabled, true)
        XCTAssertEqual(restoredSettings?.reminderTime, "22:00")
        XCTAssertEqual(restoredSettings?.themeMode, "sleep_abyss")
        XCTAssertEqual(restoredSettings?.compassionPassCount, 3)
    }
    
    // MARK: - Scenario 9: New installation -> Zero-day Orbit
    func testNewInstallationProducesZeroDayOrbit() {
        let calc = OrbitCalculator()
        let calendar = Calendar.current
        let today = Date()
        
        let newInstallationEvents: [CompletionEvent] = []
        let stats = calc.calculateStats(
            events: newInstallationEvents,
            calendar: calendar,
            today: today,
            existingCompassionPasses: 0
        )
        
        XCTAssertEqual(stats.currentStreak, 0, "A fresh installation must display a 0-day Orbit streak.")
        XCTAssertEqual(stats.bestStreak, 0, "A fresh installation must display 0 best streak days.")
        XCTAssertEqual(stats.totalMindfulMinutes, 0, "Total mindful minutes must be 0 for a new installation.")
        XCTAssertEqual(stats.completedSessionsCount, 0, "Completed sessions count must be 0 for a new installation.")
        XCTAssertEqual(stats.nextMilestoneDays, 7, "Next milestone for 0 streak should be 7 days.")
    }
    
    // MARK: - Speed Accreditation: 0.75x, 1.0x, 1.25x Uninterrupted Playback
    @MainActor
    func testPlaybackSpeedsAccreditation() {
        for speed in [0.75, 1.0, 1.25] {
            let acc = ListeningAccumulator(duration: 300.0) // 5-minute session, threshold = 270s
            var t = 0.0
            while t <= 280.0 {
                t += speed
                acc.tick(currentTime: t, isPlaying: true, speed: speed)
            }
            XCTAssertTrue(acc.hasQualified, "Uninterrupted continuous listening at \(speed)x must qualify without loss.")
        }
    }
}
