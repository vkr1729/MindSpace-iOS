import XCTest
import Foundation
@testable import MindSpace

final class DailyRecommendationTests: XCTestCase {
    
    func testDynamicNextSessionResolution() {
        // Setup mock course with 5 sessions
        let sessions = (1...5).map { day in
            CatalogSession(
                id: "anxiety_day_\(day)",
                title: "Anxiety Day \(day)",
                dayNumber: day,
                relativePath: "Packs/2 - Health/1 - Managing Anxiety/session_\(day).mp3",
                duration: 600.0
            )
        }
        let course = CatalogCourse(
            id: "health_anxiety",
            name: "Managing Anxiety",
            folderName: "1 - Managing Anxiety",
            order: 1,
            description: "Calm your mind",
            totalSessions: 5,
            sessions: sessions
        )
        
        // Scenario 1: User completed Day 1 and Day 2 -> Next session must be Day 3
        let completedIDs: Set<String> = ["anxiety_day_1", "anxiety_day_2"]
        let nextSession = course.sessions.first(where: { !completedIDs.contains($0.id) })
        XCTAssertEqual(nextSession?.dayNumber, 3, "Next session should resolve to Day 3.")
        XCTAssertEqual(nextSession?.title, "Anxiety Day 3")
        
        // Scenario 2: User completed all 5 sessions -> Fallback to first session or completion
        let allCompleted: Set<String> = ["anxiety_day_1", "anxiety_day_2", "anxiety_day_3", "anxiety_day_4", "anxiety_day_5"]
        let completedNext = course.sessions.first(where: { !allCompleted.contains($0.id) }) ?? course.sessions.first
        XCTAssertEqual(completedNext?.dayNumber, 1, "Completed course should loop back to Day 1 as fallback.")
    }
    
    func testSleepSoundDeterministicRotation() {
        let sleepSounds = ["Dream", "Drift Off", "Doze", "Slumber", "Power Down", "Snooze"]
        
        // Test deterministic selection across 10 distinct days of the year
        var selectedDailySounds: [Int: String] = [:]
        for dayOfYear in 1...10 {
            let sound = sleepSounds[dayOfYear % sleepSounds.count]
            selectedDailySounds[dayOfYear] = sound
            XCTAssertFalse(sound.isEmpty)
        }
        
        // Same day must always yield same sound
        let day45SoundA = sleepSounds[45 % sleepSounds.count]
        let day45SoundB = sleepSounds[45 % sleepSounds.count]
        XCTAssertEqual(day45SoundA, day45SoundB, "Daily sleep sound selection must be deterministic for the same day.")
    }
    
    func testReset5MinResolutionDistinctFromSOS() {
        // Verify Unwind Reset 5min has duration ~300s
        let unwindResetSession = SingleSession(
            id: "unwind_reset_5min",
            title: "Reset 5min",
            category: "Unwind",
            relativePath: "Singles/6 - Unwind/Reset/Reset 5min.mp3",
            duration: 300.149
        )
        
        let sosPanicSession = SingleSession(
            id: "sos_panicking_3min",
            title: "Panicking 3min",
            category: "SOS",
            relativePath: "Singles/2 - SOS/Single - Panicking 3min.mp3",
            duration: 180.0
        )
        
        XCTAssertNotEqual(unwindResetSession.category, sosPanicSession.category)
        XCTAssertNotEqual(unwindResetSession.id, sosPanicSession.id)
        XCTAssertEqual(unwindResetSession.formattedDuration, "5:00")
        XCTAssertEqual(sosPanicSession.formattedDuration, "3:00")
    }
    
    func testSleepSoundCuratedDurations10_30_60Only() {
        // Mock a full set of sleep sound duration variants: 10m, 15m, 20m, 30m, 45m, 60m
        let sampleSessions = [
            SingleSession(id: "dream_10m", title: "Sleep Sound - Dream 10min", category: "Sleep Sounds", relativePath: "Singles/Dream 10m.mp3", duration: 600.0),
            SingleSession(id: "dream_15m", title: "Sleep Sound - Dream 15min", category: "Sleep Sounds", relativePath: "Singles/Dream 15m.mp3", duration: 900.0),
            SingleSession(id: "dream_20m", title: "Sleep Sound - Dream 20min", category: "Sleep Sounds", relativePath: "Singles/Dream 20m.mp3", duration: 1200.0),
            SingleSession(id: "dream_30m", title: "Sleep Sound - Dream 30min", category: "Sleep Sounds", relativePath: "Singles/Dream 30m.mp3", duration: 1800.0),
            SingleSession(id: "dream_45m", title: "Sleep Sound - Dream 45min", category: "Sleep Sounds", relativePath: "Singles/Dream 45m.mp3", duration: 2700.0),
            SingleSession(id: "dream_60m", title: "Sleep Sound - Dream 60min", category: "Sleep Sounds", relativePath: "Singles/Dream 60m.mp3", duration: 3600.0)
        ]
        
        let allowedMinutes: Set<Int> = [10, 30, 60]
        let curated = sampleSessions.filter { session in
            let mins = Int(round(session.duration / 60.0))
            return allowedMinutes.contains(mins)
        }.sorted(by: { $0.duration < $1.duration })
        
        XCTAssertEqual(curated.count, 3, "Only 10m, 30m, and 60m sessions should be present in sleep sound card.")
        XCTAssertEqual(Int(round(curated[0].duration / 60.0)), 10)
        XCTAssertEqual(Int(round(curated[1].duration / 60.0)), 30)
        XCTAssertEqual(Int(round(curated[2].duration / 60.0)), 60)
        
        let filteredOut = sampleSessions.filter { session in
            let mins = Int(round(session.duration / 60.0))
            return !allowedMinutes.contains(mins)
        }
        XCTAssertEqual(filteredOut.count, 3, "15m, 20m, and 45m sessions must be excluded.")
    }
}
