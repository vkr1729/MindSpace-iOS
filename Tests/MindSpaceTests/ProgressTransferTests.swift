import XCTest
import Foundation
@testable import MindSpace

final class ProgressTransferTests: XCTestCase {
    
    func testBackupDocumentRoundTrip() throws {
        let stats = BackupStats(
            totalMindfulMinutes: 324,
            completedSessionsCount: 28,
            currentStreak: 7,
            bestStreak: 14
        )
        let settings = BackupUserSettings(
            defaultDurationMinutes: 10,
            reminderTime: "08:30",
            themeMode: "quiet_cosmos",
            hideStreak: false,
            compassionPassCount: 1
        )
        let event = BackupCompletionEvent(
            id: UUID().uuidString,
            sessionId: "sess_1_1",
            courseId: "Basics",
            timestamp: "2026-08-19T08:00:00Z",
            timeZone: "America/New_York",
            playedSeconds: 600.0,
            isQualifying: true,
            reflection: "lighter"
        )
        let achievement = BackupAchievement(id: "first_orbit", unlockedAt: "2026-08-19T08:00:00Z")
        
        let doc = MindSpaceBackupDocument(
            stats: stats,
            userSettings: settings,
            completionEvents: [event],
            favorites: ["sess_1_1"],
            achievements: [achievement]
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(doc)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MindSpaceBackupDocument.self, from: data)
        
        XCTAssertEqual(decoded.stats.totalMindfulMinutes, 324)
        XCTAssertEqual(decoded.stats.currentStreak, 7)
        XCTAssertEqual(decoded.userSettings.reminderTime, "08:30")
        XCTAssertEqual(decoded.completionEvents.count, 1)
        XCTAssertEqual(decoded.completionEvents.first?.reflection, "lighter")
        XCTAssertEqual(decoded.favorites, ["sess_1_1"])
        XCTAssertEqual(decoded.achievements.first?.id, "first_orbit")
    }
}
