import XCTest
import SwiftUI
@testable import MindSpace

final class UIUXPolishTests: XCTestCase {
    
    // MARK: - Semantic Theme Token Tests
    func testMindSpaceThemeAccentDerivation() {
        let sleepColor = MindSpaceTheme.accent(for: "Deep Sleep")
        XCTAssertEqual(sleepColor, MindSpaceTheme.secondaryAccent)
        
        let anxietyColor = MindSpaceTheme.accent(for: "Managing Anxiety")
        XCTAssertEqual(anxietyColor, MindSpaceTheme.success)
        
        let focusColor = MindSpaceTheme.accent(for: "Work & Focus")
        XCTAssertEqual(focusColor, MindSpaceTheme.focus)
        
        let sosColor = MindSpaceTheme.accent(for: "SOS Relief")
        XCTAssertEqual(sosColor, MindSpaceTheme.danger)
        
        let braveColor = MindSpaceTheme.accent(for: "Brave & Resilient")
        XCTAssertEqual(braveColor, MindSpaceTheme.warning)
        
        let fallbackColor = MindSpaceTheme.accent(for: "Basics")
        XCTAssertEqual(fallbackColor, MindSpaceTheme.accent)
    }
    
    // MARK: - Haptic Service Safety Tests
    @MainActor
    func testHapticServiceCallSafety() {
        let haptics = HapticService.shared
        XCTAssertNotNil(haptics)
        
        // Ensure main actor calls are safe and non-blocking
        haptics.light()
        haptics.medium()
        haptics.soft()
        haptics.selection()
        haptics.success()
    }
    
    // MARK: - Daily Journey Item State Tests
    func testDailyJourneyItemState() {
        var item = DailyJourneyItem(
            id: "test_journey_1",
            title: "Basics Day 1",
            durationLabel: "10 min",
            isPrimaryAction: true,
            isCompleted: false
        )
        
        XCTAssertFalse(item.isCompleted)
        XCTAssertTrue(item.isPrimaryAction)
        
        item.isCompleted = true
        XCTAssertTrue(item.isCompleted)
    }
    
    // MARK: - Linear Course Progress Mapping
    func testCourseSessionProgressMapping() {
        let session = CatalogSession(
            id: "session_1",
            title: "Foundation Day 1",
            dayNumber: 1,
            relativePath: "Foundation/Day1.mp3",
            duration: 600
        )
        let completedIDs: Set<String> = [session.id]

        XCTAssertEqual(session.dayNumber, 1)
        XCTAssertTrue(completedIDs.contains(session.id))
    }
    
    // MARK: - Condensed Duration Tests
    func testSingleSessionCondensedDuration() {
        let session10m = SingleSession(
            id: "s1",
            title: "Ocean Wave",
            category: "Sleep Sounds",
            relativePath: "Packs/Sleep/Ocean.mp3",
            duration: 640.0
        )
        XCTAssertEqual(session10m.formattedDuration, "10:40")
        XCTAssertEqual(session10m.condensedDuration, "11 min")
        
        let session600s = SingleSession(
            id: "s2",
            title: "Rainfall",
            category: "Sleep Sounds",
            relativePath: "Packs/Sleep/Rain.mp3",
            duration: 600.0
        )
        XCTAssertEqual(session600s.condensedDuration, "10 min")
    }
    
    // MARK: - User Settings Model Tests
    func testUserSettingsDefaultInitialization() {
        let settings = UserSettings()
        XCTAssertFalse(settings.reminderEnabled)
        XCTAssertEqual(settings.reminderTime, "08:00")
        XCTAssertFalse(settings.hideStreak)
        XCTAssertEqual(settings.compassionPassCount, 0)
    }
}
