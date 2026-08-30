import XCTest
import SwiftUI
@testable import MindSpace

final class QuietNativeVisualTests: XCTestCase {
    func testSemanticAccentMappingsAreStable() {
        XCTAssertEqual(MindSpaceTheme.accent(for: "Deep Sleep"), MindSpaceTheme.secondaryAccent)
        XCTAssertEqual(MindSpaceTheme.accent(for: "Managing Anxiety"), MindSpaceTheme.success)
        XCTAssertEqual(MindSpaceTheme.accent(for: "Work Focus"), MindSpaceTheme.focus)
        XCTAssertEqual(MindSpaceTheme.accent(for: "SOS Panic"), MindSpaceTheme.danger)
        XCTAssertEqual(MindSpaceTheme.accent(for: "Brave Compassion"), MindSpaceTheme.warning)
        XCTAssertEqual(MindSpaceTheme.accent(for: "Basics"), MindSpaceTheme.accent)
    }

    func testCourseSymbolsAreSystemSymbolsRatherThanAssetNames() {
        let names = ["Sleep", "Health", "Focus", "SOS", "Sport", "Compassion", "Basics"]
        for name in names {
            let symbol = MindSpaceTheme.symbolName(for: name)
            XCTAssertFalse(symbol.isEmpty)
            XCTAssertFalse(symbol.contains("planet"))
        }
    }

    func testReusableImageFreeComponentsInitializeAtAccessibleMinimumSize() {
        let badge = MindSpaceCourseBadge(name: "Basics", size: 24)
        XCTAssertEqual(badge.name, "Basics")
        XCTAssertEqual(badge.size, 44)

        let button = MindSpacePrimaryButton("Continue", systemImage: "play.fill", action: {})
        XCTAssertEqual(button.title, "Continue")
        XCTAssertEqual(button.systemImage, "play.fill")
    }
}
