import XCTest
import Foundation
@testable import MindSpace

final class OrbitCalculatorTests: XCTestCase {
    
    func testConsecutiveStreakCalculation() {
        let calc = OrbitCalculator()
        let calendar = Calendar.current
        let today = Date()
        
        var events: [CompletionEvent] = []
        // Create 5 consecutive days of qualifying meditations
        for dayOffset in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let ev = CompletionEvent(
                sessionStableId: "sess_\(dayOffset)",
                actualPlayedSeconds: 600.0,
                isQualifying: true,
                timestamp: date
            )
            events.append(ev)
        }
        
        let stats = calc.calculateStats(events: events, calendar: calendar, today: today)
        XCTAssertEqual(stats.currentStreak, 5)
        XCTAssertEqual(stats.bestStreak, 5)
        XCTAssertEqual(stats.totalMindfulMinutes, 50)
        XCTAssertEqual(stats.completedSessionsCount, 5)
    }
    
    func testCompassionPassPreventsStreakBreak() {
        let calc = OrbitCalculator()
        let calendar = Calendar.current
        let today = Date()
        
        var events: [CompletionEvent] = []
        // Practiced today (0), missed yesterday (1), practiced days 2, 3, 4
        let daysPracticed = [0, 2, 3, 4]
        for dayOffset in daysPracticed {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let ev = CompletionEvent(
                sessionStableId: "sess_\(dayOffset)",
                actualPlayedSeconds: 600.0,
                isQualifying: true,
                timestamp: date
            )
            events.append(ev)
        }
        
        // Without compassion pass: streak is 1
        let statsNoPass = calc.calculateStats(events: events, calendar: calendar, today: today, existingCompassionPasses: 0)
        XCTAssertEqual(statsNoPass.currentStreak, 1)
        
        // With 1 available compassion pass: missed day 1 is protected, streak is 4
        let statsWithPass = calc.calculateStats(events: events, calendar: calendar, today: today, existingCompassionPasses: 1)
        XCTAssertEqual(statsWithPass.currentStreak, 4)
        XCTAssertEqual(statsWithPass.compassionPassUsedCount, 1)
    }
    
    func testSensitiveTopicExemption() {
        XCTAssertTrue(OrbitCalculator.isSensitiveTopic(courseName: "Depression"))
        XCTAssertTrue(OrbitCalculator.isSensitiveTopic(courseName: "1 - Grief"))
        XCTAssertTrue(OrbitCalculator.isSensitiveTopic(courseName: "Coping with Cancer"))
        XCTAssertTrue(OrbitCalculator.isSensitiveTopic(courseName: "SOS"))
        XCTAssertFalse(OrbitCalculator.isSensitiveTopic(courseName: "Basics"))
        XCTAssertFalse(OrbitCalculator.isSensitiveTopic(courseName: "Managing Anxiety"))
    }
    
    func testAchievementsUnlockMilestones() {
        let calc = OrbitCalculator()
        let badges7 = calc.getAchievements(currentStreak: 7, totalSessions: 10)
        let firstOrbit = badges7.first(where: { $0.id == "first_orbit" })
        XCTAssertEqual(firstOrbit?.isUnlocked, true)
        
        let badges14 = calc.getAchievements(currentStreak: 14, totalSessions: 20)
        let stellarStart = badges14.first(where: { $0.id == "stellar_start" })
        XCTAssertEqual(stellarStart?.isUnlocked, true)
    }
}
