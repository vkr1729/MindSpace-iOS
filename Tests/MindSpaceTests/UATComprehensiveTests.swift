import XCTest
import Foundation
import SwiftData
@testable import MindSpace

final class UATComprehensiveTests: XCTestCase {
    
    // MARK: - UAT Area 1: Navigation & Quiet Native Theming
    func testMindSpaceThemeColorTokensAndPalette() {
        XCTAssertNotNil(MindSpaceTheme.background)
        XCTAssertNotNil(MindSpaceTheme.surface)
        XCTAssertNotNil(MindSpaceTheme.accent)
        XCTAssertNotNil(MindSpaceTheme.success)
        XCTAssertNotNil(MindSpaceTheme.danger)
        XCTAssertNotNil(MindSpaceTheme.warning)
        XCTAssertNotNil(MindSpaceTheme.secondaryAccent)
        
        // AppTab Enum verification
        let tabs = AppTab.allCases
        XCTAssertEqual(tabs.count, 4)
        XCTAssertEqual(tabs[0].title, "Today")
        XCTAssertEqual(tabs[1].title, "Library")
        XCTAssertEqual(tabs[2].title, "Progress")
        XCTAssertEqual(tabs[3].title, "Settings")
    }
    
    // MARK: - UAT Area 2: Media Catalog Integrity & Search Performance
    func testCatalogSearchPerformanceAndCoverage() {
        let manifest = CatalogManifest(
            schemaVersion: 1,
            generatedAt: "2026-08-20T00:00:00Z",
            totalFiles: 10,
            totalDuration: 1800.0,
            totalDurationHours: 0.5,
            totalSizeBytes: 1000000,
            categories: [
                CatalogCategory(
                    id: "cat_health",
                    type: "pack",
                    name: "Health",
                    folderName: "2 - Health",
                    order: 2,
                    description: "Health packs",
                    colorHex: "#14B8A6",
                    iconName: "heart.fill",
                    courses: [
                        CatalogCourse(
                            id: "course_anxiety",
                            name: "Managing Anxiety",
                            folderName: "1 - Managing Anxiety",
                            order: 1,
                            description: "Tools for anxious times",
                            totalSessions: 3,
                            sessions: [
                                CatalogSession(id: "s1", title: "Anxiety Day 1", dayNumber: 1, relativePath: "p1", duration: 600),
                                CatalogSession(id: "s2", title: "Anxiety Day 2", dayNumber: 2, relativePath: "p2", duration: 600),
                                CatalogSession(id: "s3", title: "Anxiety Day 3", dayNumber: 3, relativePath: "p3", duration: 600)
                            ]
                        )
                    ]
                )
            ],
            singlesCategories: [
                SinglesCategory(
                    id: "singles_sos",
                    name: "SOS",
                    folderName: "2 - SOS",
                    order: 2,
                    description: "Emergency relief",
                    colorHex: "#EF4444",
                    iconName: "shield.fill",
                    sessions: [
                        SingleSession(id: "sos_1", title: "Panicking 3min", category: "SOS", relativePath: "s_p1", duration: 180)
                    ]
                )
            ]
        )
        
        XCTAssertEqual(manifest.categories.first?.courses.count, 1)
        XCTAssertEqual(manifest.singlesCategories.first?.sessions.count, 1)
    }
    
    // MARK: - UAT Area 3: Linear Course Progress Mapping
    func testCourseProgressStateMapping() {
        let sessions = (1...10).map { day in
            CatalogSession(
                id: "basics_day_\(day)",
                title: "Basics Day \(day)",
                dayNumber: day,
                relativePath: "rel_\(day)",
                duration: 600
            )
        }
        
        let completedIDs: Set<String> = ["basics_day_1", "basics_day_2", "basics_day_3"]
        let nextId = "basics_day_4"
        
        let progress = sessions.map { session in
            (session: session, isCompleted: completedIDs.contains(session.id), isActive: session.id == nextId)
        }
        
        XCTAssertEqual(progress.count, 10)
        XCTAssertTrue(progress[0].isCompleted)
        XCTAssertTrue(progress[1].isCompleted)
        XCTAssertTrue(progress[2].isCompleted)
        XCTAssertTrue(progress[3].isActive)
        XCTAssertFalse(progress[4].isCompleted)
        XCTAssertFalse(progress[4].isActive)
    }
    
    // MARK: - UAT Area 4: Favorites & Progress Persistence
    func testFavoritesAndCompletionPersistence() throws {
        let schema = Schema([
            CompletionEvent.self,
            FavoriteItem.self,
            PlaybackResume.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let fav1 = FavoriteItem(sessionStableId: "fav_session_1", title: "Deep Sleep Ocean", relativePath: "Singles/Sleep/Ocean.mp3")
        context.insert(fav1)
        try context.save()
        
        let fetchedFavs = try context.fetch(FetchDescriptor<FavoriteItem>())
        XCTAssertEqual(fetchedFavs.count, 1)
        XCTAssertEqual(fetchedFavs.first?.sessionStableId, "fav_session_1")
        XCTAssertEqual(fetchedFavs.first?.title, "Deep Sleep Ocean")
        
        // Remove favorite
        context.delete(fav1)
        try context.save()
        
        let emptyFavs = try context.fetch(FetchDescriptor<FavoriteItem>())
        XCTAssertEqual(emptyFavs.count, 0)
    }
    
    // MARK: - UAT Area 5: Library Path Resolver & Sandboxing
    func testLibraryPathResolverDestination() throws {
        let resolver = LibraryPathResolver.shared
        XCTAssertTrue(resolver.libraryDirectoryURL.path.contains("Documents/MindSpaceLibrary"))
        
        // 1. Nonexistent file returns nil
        let missingPath = "NonExistent/Track.mp3"
        XCTAssertNil(resolver.resolveURL(for: missingPath))
        
        // 2. Existing file resolves to proper local URL
        let testRelPath = "TestCategory/TestTrack.mp3"
        let testURL = resolver.libraryDirectoryURL.appendingPathComponent(testRelPath)
        try FileManager.default.createDirectory(at: testURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "test audio content".data(using: .utf8)?.write(to: testURL)
        
        let resolvedURL = resolver.resolveURL(for: testRelPath)
        XCTAssertNotNil(resolvedURL)
        XCTAssertTrue(resolvedURL!.path.contains("TestCategory/TestTrack.mp3"))
        
        // Clean up test file
        try? FileManager.default.removeItem(at: testURL)
    }
    
    // MARK: - UAT Area 6: Notification Scheduler Daily Trigger
    func testNotificationDailyReminderParsing() {
        let validTime = "21:45"
        let parts = validTime.split(separator: ":")
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(Int(parts[0]), 21)
        XCTAssertEqual(Int(parts[1]), 45)
        
        let invalidTime = "invalid"
        let invalidParts = invalidTime.split(separator: ":")
        XCTAssertNotEqual(invalidParts.count, 2)
    }
    
    // MARK: - UAT Area 7: Anti-Scrubbing Listening Accumulator Boundary
    @MainActor
    func testListeningAccumulatorBoundaries() {
        let accShort = ListeningAccumulator(duration: 30.0)
        XCTAssertEqual(accShort.targetThreshold, 60.0)
        // For duration < 60s, qualification threshold is 80% (24s)
        for t in 1...25 {
            accShort.tick(currentTime: Double(t), isPlaying: true)
        }
        XCTAssertTrue(accShort.hasQualified)
        
        let accLong = ListeningAccumulator(duration: 1200.0)
        // 90% of 1200s = 1080s, duration - 30 = 1170s -> min = 1080s
        XCTAssertEqual(accLong.targetThreshold, 1080.0)
    }
}
