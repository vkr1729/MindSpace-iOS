import XCTest
import Foundation
@testable import MindSpace

final class DateFormatterCacheAndOptimizationTests: XCTestCase {
    
    func testDateFormatterCacheDayKey() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 20
        components.hour = 12
        components.minute = 0
        components.second = 0
        
        guard let testDate = calendar.date(from: components) else {
            XCTFail("Failed to create test date")
            return
        }
        
        let dayKey = DateFormatterCache.dayKey(from: testDate)
        XCTAssertEqual(dayKey, "2026-08-20")
        
        let parsedDate = DateFormatterCache.dateFromDayKey(dayKey)
        XCTAssertNotNil(parsedDate)
        
        let reparsedKey = DateFormatterCache.dayKey(from: parsedDate!)
        XCTAssertEqual(reparsedKey, "2026-08-20")
    }
    
    func testDateFormatterCacheTimeString() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = 21
        components.minute = 45
        
        guard let testDate = calendar.date(from: components) else {
            XCTFail("Failed to create test date")
            return
        }
        
        let timeStr = DateFormatterCache.timeString(from: testDate)
        XCTAssertEqual(timeStr, "21:45")
    }
    
    func testDateFormatterCacheISO8601() {
        let now = Date()
        let isoStr = DateFormatterCache.iso8601String(from: now)
        XCTAssertFalse(isoStr.isEmpty)
        
        let parsed = DateFormatterCache.dateFromISO8601(isoStr)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(Int(parsed!.timeIntervalSince1970), Int(now.timeIntervalSince1970))
    }
    
    func testDateFormatterCacheConcurrency() {
        let expectation = self.expectation(description: "Concurrent date formatting")
        expectation.expectedFulfillmentCount = 100
        
        let testDates = (0..<100).map { Date(timeIntervalSince1970: Double($0 * 86400)) }
        
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            let date = testDates[i]
            let dayKey = DateFormatterCache.dayKey(from: date)
            let iso = DateFormatterCache.iso8601String(from: date)
            XCTAssertFalse(dayKey.isEmpty)
            XCTAssertFalse(iso.isEmpty)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
