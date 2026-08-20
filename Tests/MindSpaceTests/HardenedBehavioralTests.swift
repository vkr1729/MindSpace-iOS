import XCTest
import Foundation
import SwiftData
import AVFoundation
@testable import MindSpace

final class HardenedBehavioralTests: XCTestCase {
    
    // MARK: - 1. Playback Speeds & Anti-Scrubbing Qualification
    
    @MainActor
    func testPlaybackSpeedsAccumulationAndQualification() {
        // Test 10-minute track (600s). Target threshold is 540s.
        
        // A. 1.0x Normal speed playback
        let acc1x = ListeningAccumulator(duration: 600.0)
        var t = 0.0
        while t <= 550.0 {
            t += 1.0
            acc1x.tick(currentTime: t, isPlaying: true, speed: 1.0)
        }
        XCTAssertTrue(acc1x.hasQualified, "Uninterrupted playback at 1.0x must qualify.")
        XCTAssertEqual(acc1x.accumulatedSeconds, 550.0, accuracy: 0.1)
        XCTAssertEqual(acc1x.actualPlayedSeconds, 550.0, accuracy: 0.1)
        
        // B. 0.75x Slow speed playback
        let acc075 = ListeningAccumulator(duration: 600.0)
        t = 0.0
        while t <= 550.0 {
            t += 0.75
            acc075.tick(currentTime: t, isPlaying: true, speed: 0.75)
        }
        XCTAssertTrue(acc075.hasQualified, "Uninterrupted playback at 0.75x must qualify.")
        XCTAssertEqual(acc075.accumulatedSeconds, 550.0, accuracy: 0.5)
        XCTAssertGreaterThan(acc075.actualPlayedSeconds, 550.0, "0.75x playback should take longer in real physical wall-clock time.")
        
        // C. 1.25x Fast speed playback
        let acc125 = ListeningAccumulator(duration: 600.0)
        t = 0.0
        while t <= 550.0 {
            t += 1.25
            acc125.tick(currentTime: t, isPlaying: true, speed: 1.25)
        }
        XCTAssertTrue(acc125.hasQualified, "Uninterrupted playback at 1.25x must qualify.")
        XCTAssertEqual(acc125.accumulatedSeconds, 550.0, accuracy: 0.5)
        XCTAssertLessThan(acc125.actualPlayedSeconds, 550.0, "1.25x playback should take less real physical wall-clock time.")
    }
    
    // MARK: - 2. Anti-Scrubbing Seeking Rejection
    
    @MainActor
    func testScrubbingToNearEndDoesNotQualify() {
        let acc = ListeningAccumulator(duration: 600.0)
        
        // Listen for 3 seconds
        acc.tick(currentTime: 1.0, isPlaying: true)
        acc.tick(currentTime: 2.0, isPlaying: true)
        acc.tick(currentTime: 3.0, isPlaying: true)
        XCTAssertEqual(acc.accumulatedSeconds, 2.0)
        
        // User scrubs/seeks directly to 590s (jump of 587s)
        acc.tick(currentTime: 590.0, isPlaying: true)
        
        // Listen for 2 more seconds at the end
        acc.tick(currentTime: 591.0, isPlaying: true)
        acc.tick(currentTime: 592.0, isPlaying: true)
        
        // Total accumulated track seconds is only 2 + 2 = 4 seconds!
        XCTAssertEqual(acc.accumulatedSeconds, 4.0, accuracy: 0.1)
        XCTAssertFalse(acc.hasQualified, "Scrubbing or skipping forward to the end must NEVER qualify for streak or mindful minutes.")
    }
    
    // MARK: - 3. Missing Media File Safety & Clear Error Publishing
    
    @MainActor
    func testMissingMediaReturnsNilAndPublishesClearError() {
        let engine = PlaybackEngine.shared
        let missingTrack = PlayableTrack(
            id: "missing_track_999",
            title: "Missing Galaxy Sound",
            courseName: "Cosmos",
            relativePath: "NonExistent/MissingTrack.mp3",
            duration: 600.0
        )
        
        engine.loadAndPlay(track: missingTrack)
        
        // Must NOT be in playing state
        XCTAssertNotEqual(engine.state, .playing, "PlaybackEngine must not enter playing state when media file is missing.")
        XCTAssertEqual(engine.state, .idle)
        
        // Must publish clear user-facing error
        XCTAssertNotNil(engine.playbackError)
        XCTAssertTrue(engine.playbackError!.contains("Media file not found: Missing Galaxy Sound"))
    }
    
    // MARK: - 4. Resume Position Saving & Clearing on Qualifying Completion
    
    func testResumeSaveRestoreAndClearLifecycle() async throws {
        let schema = Schema([
            CompletionEvent.self,
            PlaybackResume.self,
            FavoriteItem.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let actor = ProgressActor(modelContainer: container)
        
        let trackId = "sess_basics_01"
        let relPath = "Packs/1 - Foundation/Basics/Day 01.mp3"
        let title = "Basics — Day 1"
        
        // 1. Save resume position at 120s
        try await actor.updateResumePosition(
            sessionStableId: trackId,
            relativePath: relPath,
            title: title,
            courseName: "Basics",
            position: 120.0,
            duration: 600.0
        )
        
        // 2. Fetch resume
        let savedResume = try await actor.fetchResume(for: trackId)
        XCTAssertNotNil(savedResume)
        XCTAssertEqual(savedResume?.lastPositionSeconds, 120.0)
        XCTAssertEqual(savedResume?.sessionTitle, title)
        
        // 3. Update resume to 250s (e.g. on pause/10s interval)
        try await actor.updateResumePosition(
            sessionStableId: trackId,
            relativePath: relPath,
            title: title,
            courseName: "Basics",
            position: 250.0,
            duration: 600.0
        )
        
        let updatedResume = try await actor.fetchResume(for: trackId)
        XCTAssertEqual(updatedResume?.lastPositionSeconds, 250.0)
        
        // 4. On qualifying completion, clear resume position
        try await actor.deleteResume(sessionStableId: trackId)
        
        let clearedResume = try await actor.fetchResume(for: trackId)
        XCTAssertNil(clearedResume, "Resume must be deleted once a qualifying completion is recorded.")
    }
    
    // MARK: - 5. Completion Recording with Exact UUID & Reflection Note
    
    func testCompletionRecordingWithExactUUIDAndReflection() async throws {
        let schema = Schema([
            CompletionEvent.self,
            PlaybackResume.self,
            FavoriteItem.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let actor = ProgressActor(modelContainer: container)
        
        // 1. Record completion before presentation
        let completionId = try await actor.recordCompletion(
            sessionStableId: "session_mindful_5",
            courseId: "Basics",
            playedSeconds: 580.0,
            isQualifying: true,
            reflection: nil
        )
        
        XCTAssertNotNil(completionId)
        
        // 2. User attaches emotional reflection on completion screen
        try await actor.saveReflection(for: completionId, note: "lighter")
        
        // 3. Verify exact event was updated with the reflection note
        let events = try await actor.fetchAllCompletionEvents()
        let targetEvent = events.first(where: { $0.id == completionId })
        
        XCTAssertNotNil(targetEvent)
        XCTAssertEqual(targetEvent?.reflectionNote, "lighter")
        XCTAssertEqual(targetEvent?.sessionStableId, "session_mindful_5")
        XCTAssertEqual(targetEvent?.actualPlayedSeconds, 580.0)
        XCTAssertEqual(targetEvent?.isQualifyingMeditation, true)
    }
    
    // MARK: - 6. 0-Day Orbit for New User & Real Streak Calculation
    
    func testZeroDayOrbitForNewUserAndStreaks() {
        let calc = OrbitCalculator()
        let calendar = Calendar.current
        let today = Date()
        
        // A. New user with 0 completed sessions
        let newStats = calc.calculateStats(events: [], calendar: calendar, today: today, existingCompassionPasses: 0)
        XCTAssertEqual(newStats.currentStreak, 0, "A new user must have 0 current streak days.")
        XCTAssertEqual(newStats.bestStreak, 0, "A new user must have 0 best streak days.")
        XCTAssertEqual(newStats.totalMindfulMinutes, 0)
        XCTAssertEqual(newStats.completedSessionsCount, 0)
        XCTAssertEqual(newStats.nextMilestoneDays, 7)
        
        // B. Practicing today creates 1-day Orbit
        let todayEvent = CompletionEvent(
            sessionStableId: "today_1",
            courseId: "Basics",
            actualPlayedSeconds: 600.0,
            isQualifying: true,
            timestamp: today
        )
        let stats1 = calc.calculateStats(events: [todayEvent], calendar: calendar, today: today)
        XCTAssertEqual(stats1.currentStreak, 1)
        XCTAssertEqual(stats1.bestStreak, 1)
        XCTAssertEqual(stats1.totalMindfulMinutes, 10)
    }
    
    // MARK: - 7. Backup Export & Restore Full Portability
    
    func testBackupExportAndRestoreWithFavoritesResumesAndReminderEnabled() throws {
        let schema = Schema([
            CompletionEvent.self,
            FavoriteItem.self,
            PlaybackResume.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        // 1. Create source state
        let event = CompletionEvent(
            sessionStableId: "sess_source_1",
            courseId: "Basics",
            actualPlayedSeconds: 600.0,
            isQualifying: true,
            reflection: "grounded",
            timestamp: Date(),
            timeZoneIdentifier: "America/Los_Angeles"
        )
        let fav = FavoriteItem(
            sessionStableId: "fav_source_1",
            title: "Ocean Waves",
            relativePath: "Singles/Sleep/Ocean.mp3"
        )
        let resume = PlaybackResume(
            sessionStableId: "resume_source_1",
            relativePath: "Packs/Basics/Day02.mp3",
            sessionTitle: "Basics — Day 2",
            courseName: "Basics",
            position: 180.0,
            duration: 600.0
        )
        let settings = UserSettings(
            defaultDuration: 15,
            reminderTime: "07:30",
            reminderEnabled: true,
            themeMode: "quiet_cosmos",
            hideStreak: false,
            compassionPassCount: 2
        )
        
        let stats = OrbitStats(
            currentStreak: 5,
            bestStreak: 10,
            totalMindfulMinutes: 50,
            completedSessionsCount: 5,
            nextMilestoneDays: 7,
            compassionPassesAvailable: 2,
            compassionPassUsedCount: 0,
            activeDates: [],
            dailyMinutes: [:]
        )
        
        // 2. Export to backup document
        let doc = ProgressTransferManager.shared.createBackupDocument(
            events: [event],
            favorites: [fav],
            settings: settings,
            orbitStats: stats,
            resumes: [resume]
        )
        
        XCTAssertEqual(doc.userSettings.reminderEnabled, true, "reminderEnabled must be included in backup.")
        XCTAssertEqual(doc.favorites, ["fav_source_1"])
        XCTAssertEqual(doc.resumes?.count, 1)
        XCTAssertEqual(doc.resumes?.first?.sessionStableId, "resume_source_1")
        XCTAssertEqual(doc.resumes?.first?.lastPositionSeconds, 180.0)
        
        // 3. Clean restore into context
        try ProgressTransferManager.shared.applyImport(
            document: doc,
            modelContext: context,
            isCleanRestore: true
        )
        
        // 4. Assert all elements are cleanly restored
        let restoredEvents = try context.fetch(FetchDescriptor<CompletionEvent>())
        XCTAssertEqual(restoredEvents.count, 1)
        XCTAssertEqual(restoredEvents.first?.sessionStableId, "sess_source_1")
        XCTAssertEqual(restoredEvents.first?.timeZoneIdentifier, "America/Los_Angeles")
        
        let restoredFavs = try context.fetch(FetchDescriptor<FavoriteItem>())
        XCTAssertEqual(restoredFavs.count, 1)
        XCTAssertEqual(restoredFavs.first?.sessionStableId, "fav_source_1")
        
        let restoredResumes = try context.fetch(FetchDescriptor<PlaybackResume>())
        XCTAssertEqual(restoredResumes.count, 1)
        XCTAssertEqual(restoredResumes.first?.sessionStableId, "resume_source_1")
        XCTAssertEqual(restoredResumes.first?.lastPositionSeconds, 180.0)
        
        let restoredSettings = try context.fetch(FetchDescriptor<UserSettings>()).first
        XCTAssertEqual(restoredSettings?.reminderEnabled, true)
        XCTAssertEqual(restoredSettings?.reminderTime, "07:30")
        XCTAssertEqual(restoredSettings?.defaultDurationMinutes, 15)
        XCTAssertEqual(restoredSettings?.compassionPassCount, 2)
    }
    
    // MARK: - 8. Real Library Verification (No Hardcoded Shortcuts)
    
    func testRealLibraryVerificationReportsAccurateCounts() async throws {
        let resolver = LibraryPathResolver.shared
        
        // Create mock manifest with 2 items
        let testPath1 = "TestMedia/Track1.mp3"
        let testPath2 = "TestMedia/Track2.mp3"
        
        let fullURL1 = resolver.libraryDirectoryURL.appendingPathComponent(testPath1)
        try FileManager.default.createDirectory(at: fullURL1.deletingLastPathComponent(), withIntermediateDirectories: true)
        let sampleData = "Sample audio stream content".data(using: .utf8)!
        try sampleData.write(to: fullURL1)
        
        let manifest = CatalogManifest(
            schemaVersion: 1,
            generatedAt: "2026-08-20T00:00:00Z",
            totalFiles: 2,
            totalDuration: 1200.0,
            totalDurationHours: 0.33,
            totalSizeBytes: Int64(sampleData.count * 2),
            categories: [
                CatalogCategory(
                    id: "cat_test",
                    type: "pack",
                    name: "Test Pack",
                    folderName: "Test Pack",
                    order: 1,
                    description: "Test description",
                    colorHex: "#6344E0",
                    iconName: "sparkles",
                    courses: [
                        CatalogCourse(
                            id: "course_test",
                            name: "Test Course",
                            folderName: "Test Course",
                            order: 1,
                            description: "Test",
                            totalSessions: 2,
                            sessions: [
                                CatalogSession(id: "ts_1", title: "Track 1", dayNumber: 1, relativePath: testPath1, duration: 600, sizeBytes: Int64(sampleData.count)),
                                CatalogSession(id: "ts_2", title: "Track 2", dayNumber: 2, relativePath: testPath2, duration: 600, sizeBytes: 5000) // Missing file
                            ]
                        )
                    ]
                )
            ],
            singlesCategories: []
        )
        
        // Perform real scan
        let report = await resolver.verifyAllCatalogEntries(manifest: manifest, validateChecksums: false)
        
        XCTAssertEqual(report.totalTracks, 2)
        XCTAssertEqual(report.foundCount, 1, "Exactly 1 track exists on disk.")
        XCTAssertEqual(report.missingCount, 1, "Exactly 1 track is missing.")
        XCTAssertFalse(report.isFullyVerified, "Report must NOT be 100% verified when files are missing.")
        XCTAssertEqual(report.missingPaths, [testPath2])
        
        // Clean up test file
        try? FileManager.default.removeItem(at: fullURL1)
    }
}
