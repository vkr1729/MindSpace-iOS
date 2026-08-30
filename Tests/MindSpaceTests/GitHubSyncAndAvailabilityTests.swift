import XCTest
import Foundation
@testable import MindSpace

final class GitHubSyncAndAvailabilityTests: XCTestCase {
    
    @MainActor
    func testKeychainManagerSaveAndRetrieve() {
        let key = "test_test_sync_key"
        let token = "ghp_mock_token_123456"
        
        let saved = KeychainManager.shared.save(key: key, value: token)
        XCTAssertTrue(saved)
        
        let retrieved = KeychainManager.shared.get(key: key)
        XCTAssertEqual(retrieved, token)
        
        let deleted = KeychainManager.shared.delete(key: key)
        XCTAssertTrue(deleted)
        
        let afterDelete = KeychainManager.shared.get(key: key)
        XCTAssertNil(afterDelete)
    }
    
    @MainActor
    func testGitHubSyncServiceConfiguration() {
        let sync = GitHubSyncService.shared
        sync.savedRepo = "owner/private-content-repo"
        sync.savedPAT = "mock_pat_test"
        
        XCTAssertTrue(sync.isConfigured)
        XCTAssertEqual(sync.savedRepo, "owner/private-content-repo")
        XCTAssertEqual(sync.savedPAT, "mock_pat_test")
    }
    
    func testLibraryFilterEnumIncludesAvailable() {
        let allFilters = LibraryFilter.allCases
        XCTAssertTrue(allFilters.contains(.available))
        XCTAssertEqual(allFilters[0], .all)
        XCTAssertEqual(allFilters[1], .available)
        XCTAssertEqual(LibraryFilter.available.rawValue, "Available")
    }
    
    func testCourseAvailabilityCalculation() {
        let session1 = CatalogSession(
            id: "test_s1",
            title: "Day 01",
            dayNumber: 1,
            relativePath: "NonExistent/Day01.mp3",
            duration: 600,
            sizeBytes: 1024,
            sha256: "dummy_sha"
        )
        let course = CatalogCourse(
            id: "test_course",
            name: "Basics",
            folderName: "Basics",
            order: 1,
            description: "Basics test",
            totalSessions: 1,
            hasGapWaiver: false,
            introVideo: nil,
            sessions: [session1]
        )
        
        let isAvailable = LibraryPathResolver.shared.isCourseAvailable(course: course)
        XCTAssertFalse(isAvailable, "Course with missing media files must report unavailable")
        
        let trackCount = LibraryPathResolver.shared.courseAvailableTrackCount(course: course)
        XCTAssertEqual(trackCount.total, 1)
        XCTAssertEqual(trackCount.found, 0)
        
        let totalSize = LibraryPathResolver.shared.courseTotalSizeBytes(course: course)
        XCTAssertEqual(totalSize, 1024)
    }
}
