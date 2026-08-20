import XCTest
import SwiftUI
@testable import MindSpace

final class UIUXPolishTests: XCTestCase {
    
    // MARK: - Ambient Theme Token Tests
    func testCosmosThemeAmbientColorDerivation() {
        let sleepColor = CosmosTheme.ambientColor(for: "Deep Sleep Sanctuary")
        XCTAssertEqual(sleepColor, CosmosTheme.moonLavender)
        
        let anxietyColor = CosmosTheme.ambientColor(for: "Managing Anxiety")
        XCTAssertEqual(anxietyColor, CosmosTheme.auroraTeal)
        
        let focusColor = CosmosTheme.ambientColor(for: "Work & Focus")
        XCTAssertEqual(focusColor, CosmosTheme.celestialBlue)
        
        let sosColor = CosmosTheme.ambientColor(for: "SOS Relief")
        XCTAssertEqual(sosColor, CosmosTheme.solarCoral)
        
        let braveColor = CosmosTheme.ambientColor(for: "Brave & Resilient")
        XCTAssertEqual(braveColor, CosmosTheme.starlightGold)
        
        let fallbackColor = CosmosTheme.ambientColor(for: "Basics")
        XCTAssertEqual(fallbackColor, CosmosTheme.cosmicPurple)
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
    
    // MARK: - Constellation Node Visual Attributes
    func testConstellationNodeVisualMapping() {
        let node = ConstellationNode(
            id: "node_1",
            dayNumber: 1,
            title: "Foundation Day 1",
            isCompleted: true,
            isActive: false,
            isBridgeOfReflection: false
        )
        
        XCTAssertEqual(node.dayNumber, 1)
        XCTAssertTrue(node.isCompleted)
        XCTAssertFalse(node.isActive)
        XCTAssertFalse(node.isBridgeOfReflection)
    }
    
    // MARK: - Condensed Duration Tests
    func testSingleSessionCondensedDuration() {
        let session10m = SingleSession(
            id: "s1",
            title: "Ocean Wave",
            category: "Sleep Sounds",
            duration: 640.0, // 10m 40s
            relativePath: "Packs/Sleep/Ocean.mp3",
            sizeBytes: 1000,
            sha256: "abc",
            codec: "mp3"
        )
        XCTAssertEqual(session10m.formattedDuration, "10:40")
        XCTAssertEqual(session10m.condensedDuration, "11 min")
        
        let session600s = SingleSession(
            id: "s2",
            title: "Rainfall",
            category: "Sleep Sounds",
            duration: 600.0, // 10m 00s
            relativePath: "Packs/Sleep/Rain.mp3",
            sizeBytes: 1000,
            sha256: "abc",
            codec: "mp3"
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
