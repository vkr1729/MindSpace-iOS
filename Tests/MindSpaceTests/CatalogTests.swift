import XCTest
import Foundation
@testable import MindSpace

final class CatalogTests: XCTestCase {
    
    func testCatalogManifestLoadsSuccessfully() throws {
        var catalogData: Data?
        if let url = Bundle.main.url(forResource: "catalog", withExtension: "json") {
            catalogData = try? Data(contentsOf: url)
        }
        
        if catalogData == nil {
            let currentDir = FileManager.default.currentDirectoryPath
            let altURL = URL(fileURLWithPath: currentDir).appendingPathComponent("Resources/catalog.json")
            if FileManager.default.fileExists(atPath: altURL.path) {
                catalogData = try? Data(contentsOf: altURL)
            }
        }
        
        guard let data = catalogData else {
            XCTFail("catalog.json not found in bundle or Resources/")
            return
        }
        
        let manifest = try JSONDecoder().decode(CatalogManifest.self, from: data)
        XCTAssertEqual(manifest.totalFiles, 905)
        XCTAssertEqual(manifest.categories.count, 8)
        XCTAssertEqual(manifest.singlesCategories.count, 15)
    }
    
    func testTotalCoursesAndSinglesCount() throws {
        var catalogData: Data?
        if let url = Bundle.main.url(forResource: "catalog", withExtension: "json") {
            catalogData = try? Data(contentsOf: url)
        } else {
            let altURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/catalog.json")
            catalogData = try? Data(contentsOf: altURL)
        }
        
        guard let data = catalogData else {
            XCTFail("catalog.json not found")
            return
        }
        
        let manifest = try JSONDecoder().decode(CatalogManifest.self, from: data)
        let totalCourses = manifest.categories.reduce(0) { $0 + $1.courses.count }
        XCTAssertEqual(totalCourses, 44)
        
        let totalSingles = manifest.singlesCategories.reduce(0) { $0 + $1.sessions.count }
        XCTAssertEqual(totalSingles, 151)
    }
    
    func testUUIDv5Uniqueness() throws {
        var catalogData: Data?
        if let url = Bundle.main.url(forResource: "catalog", withExtension: "json") {
            catalogData = try? Data(contentsOf: url)
        } else {
            let altURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/catalog.json")
            catalogData = try? Data(contentsOf: altURL)
        }
        
        guard let data = catalogData else {
            XCTFail("catalog.json not found")
            return
        }
        
        let manifest = try JSONDecoder().decode(CatalogManifest.self, from: data)
        var allIDs = Set<String>()
        var duplicateCount = 0
        
        for cat in manifest.categories {
            for course in cat.courses {
                if let intro = course.introVideo {
                    if allIDs.contains(intro.id) { duplicateCount += 1 }
                    allIDs.insert(intro.id)
                }
                for session in course.sessions {
                    if allIDs.contains(session.id) { duplicateCount += 1 }
                    allIDs.insert(session.id)
                    for v in session.videoAttachments ?? [] {
                        if allIDs.contains(v.id) { duplicateCount += 1 }
                        allIDs.insert(v.id)
                    }
                }
            }
        }
        
        for singleCat in manifest.singlesCategories {
            for session in singleCat.sessions {
                if allIDs.contains(session.id) { duplicateCount += 1 }
                allIDs.insert(session.id)
            }
        }
        
        XCTAssertEqual(duplicateCount, 0)
        XCTAssertEqual(allIDs.count, 905)
    }
    
    func testPregnancyGapWaiver() throws {
        var catalogData: Data?
        if let url = Bundle.main.url(forResource: "catalog", withExtension: "json") {
            catalogData = try? Data(contentsOf: url)
        } else {
            let altURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/catalog.json")
            catalogData = try? Data(contentsOf: altURL)
        }
        
        guard let data = catalogData else {
            XCTFail("catalog.json not found")
            return
        }
        
        let manifest = try JSONDecoder().decode(CatalogManifest.self, from: data)
        let healthCat = manifest.categories.first(where: { $0.name == "Health" })
        XCTAssertNotNil(healthCat)
        let pregnancyCourse = healthCat?.courses.first(where: { $0.folderName.contains("Pregnancy") })
        XCTAssertNotNil(pregnancyCourse)
        XCTAssertEqual(pregnancyCourse?.hasGapWaiver, true)
    }
}
