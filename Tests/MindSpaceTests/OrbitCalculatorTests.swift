import Testing
import Foundation
@testable import MindSpace

struct OrbitCalculatorTests {
    
    @Test func testConsecutiveStreakCalculation() {
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
        #expect(stats.currentStreak == 5)
        #expect(stats.bestStreak == 5)
        #expect(stats.totalMindfulMinutes == 50)
        #expect(stats.completedSessionsCount == 5)
    }
    
    @Test func testCompassionPassPreventsStreakBreak() {
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
        #expect(statsNoPass.currentStreak == 1)
        
        // With 1 available compassion pass: missed day 1 is protected, streak is 4
        let statsWithPass = calc.calculateStats(events: events, calendar: calendar, today: today, existingCompassionPasses: 1)
        #expect(statsWithPass.currentStreak == 4)
        #expect(statsWithPass.compassionPassUsedCount == 1)
    }
    
    @Test func testSensitiveTopicExemption() {
        #expect(OrbitCalculator.isSensitiveTopic(courseName: "Depression") == true)
        #expect(OrbitCalculator.isSensitiveTopic(courseName: "1 - Grief") == true)
        #expect(OrbitCalculator.isSensitiveTopic(courseName: "Coping with Cancer") == true)
        #expect(OrbitCalculator.isSensitiveTopic(courseName: "SOS") == true)
        #expect(OrbitCalculator.isSensitiveTopic(courseName: "Basics") == false)
        #expect(OrbitCalculator.isSensitiveTopic(courseName: "Managing Anxiety") == false)
    }
    
    @Test func testAchievementsUnlockMilestones() {
        let calc = OrbitCalculator()
        let badges7 = calc.getAchievements(currentStreak: 7, totalSessions: 10)
        let firstOrbit = badges7.first(where: { $0.id == "first_orbit" })
        #expect(firstOrbit?.isUnlocked == true)
        
        let badges14 = calc.getAchievements(currentStreak: 14, totalSessions: 20)
        let stellarStart = badges14.first(where: { $0.id == "stellar_start" })
        #expect(stellarStart?.isUnlocked == true)
    }
}
