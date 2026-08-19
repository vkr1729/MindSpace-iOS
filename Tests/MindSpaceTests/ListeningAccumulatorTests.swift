import XCTest
import Foundation
@testable import MindSpace

final class ListeningAccumulatorTests: XCTestCase {
    
    @MainActor
    func testThresholdCalculation() {
        // 10-minute session (600s): threshold = max(60, min(540, 570)) = 540s
        let acc10 = ListeningAccumulator(duration: 600)
        XCTAssertEqual(acc10.targetThreshold, 540.0)
        
        // 2-minute session (120s): threshold = max(60, min(108, 90)) = 90s
        let acc2 = ListeningAccumulator(duration: 120)
        XCTAssertEqual(acc2.targetThreshold, 90.0)
        
        // 45-second session (45s): targetThreshold = 60s
        let accShort = ListeningAccumulator(duration: 45)
        XCTAssertEqual(accShort.targetThreshold, 60.0)
    }
    
    @MainActor
    func testRealtimeAccumulation() {
        let acc = ListeningAccumulator(duration: 600)
        XCTAssertEqual(acc.accumulatedSeconds, 0.0)
        XCTAssertFalse(acc.hasQualified)
        
        // Simulate normal 1-second ticks
        acc.tick(currentTime: 1.0, isPlaying: true)
        acc.tick(currentTime: 2.0, isPlaying: true)
        acc.tick(currentTime: 3.0, isPlaying: true)
        
        XCTAssertEqual(acc.accumulatedSeconds, 2.0)
    }
    
    @MainActor
    func testAntiScrubbingSkipRejection() {
        let acc = ListeningAccumulator(duration: 600)
        
        // Listen for 5 seconds normally
        for t in 1...5 {
            acc.tick(currentTime: Double(t), isPlaying: true)
        }
        XCTAssertEqual(acc.accumulatedSeconds, 4.0)
        
        // User scrubs/skips from 5s to 550s (jump of 545s)
        acc.tick(currentTime: 550.0, isPlaying: true)
        // delta > 1.5s should NOT be accumulated
        XCTAssertEqual(acc.accumulatedSeconds, 4.0)
        XCTAssertFalse(acc.hasQualified)
    }
    
    @MainActor
    func testQualificationUponMeetingThreshold() {
        let acc = ListeningAccumulator(duration: 100) // targetThreshold = 70s
        
        // Simulate 75 normal seconds of continuous listening
        for t in 1...75 {
            acc.tick(currentTime: Double(t), isPlaying: true)
        }
        
        XCTAssertEqual(acc.accumulatedSeconds, 74.0)
        XCTAssertTrue(acc.hasQualified)
    }
}
