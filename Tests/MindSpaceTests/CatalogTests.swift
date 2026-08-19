import Testing
import Foundation
@testable import MindSpace

struct CatalogTests {
    
    @Test func testCatalogManifestLoadsSuccessfully() throws {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            // If running in test bundle, try relative path
            let currentDir = FileManager.default.currentDirectoryPath
            let altURL = URL(fileURLWithPath: currentDir).appendingPathComponent("Resources/catalog.json")
            #expect(FileManager.default.fileExists(atPath: altURL.path))
            let data = try Data(contentsOf: altURL)
            let manifest = try JSONDecoder().decode(CatalogManifest.self, from: data)
            #expect(manifest.totalFiles == 905)
            #expect(manifest.categories.count == 8)
            #expect(manifest.singlesCategories.count == 15)
            return
        }
        
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(CatalogManifest.self, from: data)
        #expect(manifest.totalFiles == 905)
        #expect(manifest.categories.count == 8)
        #expect(manifest.singlesCategories.count == 15)
    }
    
    @Test func testTotalCoursesAndSinglesCount() throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let catalogURL = URL(fileURLWithPath: currentDir).appendingPathComponent("Resources/catalog.json")
        let data = try Data(contentsOf: catalogURL)
        let manifest = try JSONDecoder().decode(CatalogManifest.self, from: data)
        
        let totalCourses = manifest.categories.reduce(0) { $0 + $1.courses.count }
        #expect(totalCourses == 44)
        
        let totalSingles = manifest.singlesCategories.reduce(0) { $0 + $1.sessions.count }
        #expect(totalSingles == 151)
    }
    
    @Test func testUUIDv5Uniqueness() throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let catalogURL = URL(fileURLWithPath: currentDir).appendingPathComponent("Resources/catalog.json")
        let data = try Data(contentsOf: catalogURL)
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
        
        #expect(duplicateCount == 0)
        #expect(allIDs.count == 905)
    }
    
    @Test func testPregnancyGapWaiver() throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let catalogURL = URL(fileURLWithPath: currentDir).appendingPathComponent("Resources/catalog.json")
        let data = try Data(contentsOf: catalogURL)
        let manifest = try JSONDecoder().decode(CatalogManifest.self, from: data)
        
        let healthCat = manifest.categories.first(where: { $0.name == "Health" })
        #expect(healthCat != nil)
        let pregnancyCourse = healthCat?.courses.first(where: { $0.folderName.contains("Pregnancy") })
        #expect(pregnancyCourse != nil)
        #expect(pregnancyCourse?.hasGapWaiver == true)
    }
}
