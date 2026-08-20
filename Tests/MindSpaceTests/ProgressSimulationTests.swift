import XCTest
import Foundation
import SwiftData
@testable import MindSpace

final class ProgressSimulationTests: XCTestCase {
    
    func testMultiDayTwoCourseSimulationWithCompassionPassAndAchievements() {
        let calc = OrbitCalculator()
        let calendar = Calendar.current
        let today = Date()
        
        var events: [CompletionEvent] = []
        
        // Simulate a 35-day user journey:
        // Days 1-10: Basics course (10 sessions, 10 min each = 600s)
        // Days 11-25: Managing Anxiety course (15 sessions, 15 min each = 900s)
        // Day 18 is missed (protected by earned compassion pass)
        // Days 26-35: Additional practice (10 min each = 600s)
        
        let missedDayOffset = 18
        var expectedTotalMinutes = 0
        var expectedSessionCount = 0
        
        for dayOffset in 0..<35 {
            if dayOffset == missedDayOffset {
                // Missed day - no event added
                continue
            }
            
            let eventDate = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let durationSeconds: Double
            let courseId: String
            let sessionId: String
            
            if dayOffset < 10 {
                courseId = "Foundation_Basics"
                sessionId = "basics_day_\(10 - dayOffset)"
                durationSeconds = 600.0 // 10 mins
            } else if dayOffset < 25 {
                courseId = "Health_ManagingAnxiety"
                sessionId = "anxiety_day_\(25 - dayOffset)"
                durationSeconds = 900.0 // 15 mins
            } else {
                courseId = "Foundation_Basics"
                sessionId = "basics_review_\(35 - dayOffset)"
                durationSeconds = 600.0 // 10 mins
            }
            
            let ev = CompletionEvent(
                sessionStableId: sessionId,
                courseId: courseId,
                actualPlayedSeconds: durationSeconds,
                isQualifying: true,
                reflection: "Peaceful reflection for day offset \(dayOffset)",
                timestamp: eventDate
            )
            events.append(ev)
            expectedTotalMinutes += Int(durationSeconds / 60.0)
            expectedSessionCount += 1
        }
        
        // Calculate orbit stats with initial 0 passes (user will earn passes at 7, 14, 21, 28 days)
        let stats = calc.calculateStats(
            events: events,
            calendar: calendar,
            today: today,
            existingCompassionPasses: 0
        )
        
        // 1. Validate Streak Protection via Compassion Pass
        // 34 practiced days + 1 protected missed day = 35-day streak
        XCTAssertEqual(stats.currentStreak, 35, "Streak should remain unbroken at 35 days thanks to compassion pass protection.")
        XCTAssertEqual(stats.bestStreak, 35, "Best streak should be 35 days.")
        XCTAssertGreaterThanOrEqual(stats.compassionPassUsedCount, 1, "Should have used 1 compassion pass for day 18.")
        
        // 2. Validate Mindful Minutes and Sessions Count
        XCTAssertEqual(stats.totalMindfulMinutes, expectedTotalMinutes, "Total mindful minutes must exactly match sum of all sessions.")
        XCTAssertEqual(stats.completedSessionsCount, expectedSessionCount, "Completed sessions count must match total qualifying sessions.")
        
        // 3. Validate Achievements Unlock States
        let achievements = calc.getAchievements(
            currentStreak: stats.currentStreak,
            totalSessions: stats.completedSessionsCount
        )
        
        let firstOrbit = achievements.first(where: { $0.id == "first_orbit" })
        XCTAssertEqual(firstOrbit?.isUnlocked, true, "7-day First Orbit must be unlocked.")
        
        let stellarStart = achievements.first(where: { $0.id == "stellar_start" })
        XCTAssertEqual(stellarStart?.isUnlocked, true, "14-day Stellar Start must be unlocked.")
        
        let deepSpace = achievements.first(where: { $0.id == "deep_space" })
        XCTAssertEqual(deepSpace?.isUnlocked, true, "30-day Deep Space must be unlocked.")
        
        let century = achievements.first(where: { $0.id == "century_constellation" })
        XCTAssertEqual(century?.isUnlocked, false, "100-session achievement should remain locked at 34 sessions.")
        
        // 4. Validate Heatmap Activity Dates and Daily Minutes
        XCTAssertEqual(stats.activeDates.count, 34, "Heatmap active dates count must be 34 days.")
        XCTAssertEqual(stats.dailyMinutes.count, 34, "Daily minutes dictionary must have 34 day entries.")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        
        let missedKey = formatter.string(from: calendar.date(byAdding: .day, value: -missedDayOffset, to: today)!)
        XCTAssertNil(stats.dailyMinutes[missedKey], "Missed day should have no minutes in heatmap.")
        
        let todayKey = formatter.string(from: today)
        XCTAssertEqual(stats.dailyMinutes[todayKey], 10, "Today's meditation should record 10 minutes.")
    }
    
    func testCourseProgressFilteringExcludesUnstartedCourses() {
        let completedIDs: Set<String> = ["basics_day_1", "basics_day_2", "basics_day_3"]
        
        // Simulate course 1: Basics (has 3 completed sessions)
        let basicsSessions = [
            CatalogSession(id: "basics_day_1", dayNumber: 1, title: "Day 1", duration: 600, formattedDuration: "10:00", relativePath: "p1"),
            CatalogSession(id: "basics_day_2", dayNumber: 2, title: "Day 2", duration: 600, formattedDuration: "10:00", relativePath: "p2"),
            CatalogSession(id: "basics_day_3", dayNumber: 3, title: "Day 3", duration: 600, formattedDuration: "10:00", relativePath: "p3"),
            CatalogSession(id: "basics_day_4", dayNumber: 4, title: "Day 4", duration: 600, formattedDuration: "10:00", relativePath: "p4")
        ]
        let basicsCourse = CatalogCourse(id: "c_basics", name: "Basics", folderName: "Basics", totalSessions: 4, description: "Foundation", sessions: basicsSessions)
        
        // Simulate course 2: Sleep (0 completed sessions)
        let sleepSessions = [
            CatalogSession(id: "sleep_day_1", dayNumber: 1, title: "Day 1", duration: 600, formattedDuration: "10:00", relativePath: "s1")
        ]
        let sleepCourse = CatalogCourse(id: "c_sleep", name: "Sleep", folderName: "Sleep", totalSessions: 1, description: "Rest", sessions: sleepSessions)
        
        let allCourses = [basicsCourse, sleepCourse]
        
        let inProgress = allCourses.compactMap { course -> (CatalogCourse, Int)? in
            let done = course.sessions.filter { completedIDs.contains($0.id) }.count
            if done > 0 {
                return (course, done)
            }
            return nil
        }
        
        XCTAssertEqual(inProgress.count, 1, "Only started courses should be in progress.")
        XCTAssertEqual(inProgress.first?.0.name, "Basics", "Basics should be the only in-progress course.")
        XCTAssertEqual(inProgress.first?.1, 3, "Basics should report 3 completed sessions.")
    }
}
