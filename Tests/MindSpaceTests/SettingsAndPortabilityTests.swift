import XCTest
import Foundation
import SwiftData
@testable import MindSpace

final class SettingsAndPortabilityTests: XCTestCase {
    
    func testExportAndImportMergeModePreservesAndDeduplicatesRecords() throws {
        let manager = ProgressTransferManager.shared
        
        let schema = Schema([
            CompletionEvent.self,
            FavoriteItem.self,
            PlaybackResume.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        // 1. Insert existing local completion event
        let existingId = UUID()
        let existingEvent = CompletionEvent(
            sessionStableId: "local_sess_1",
            courseId: "Basics",
            actualPlayedSeconds: 600.0,
            isQualifying: true,
            reflection: "Existing reflection",
            timestamp: Date().addingTimeInterval(-86400)
        )
        existingEvent.id = existingId
        context.insert(existingEvent)
        try context.save()
        
        // 2. Create a backup document with 1 overlapping event and 1 new event
        let backupEvent1 = BackupCompletionEvent(
            id: existingId.uuidString,
            sessionId: "local_sess_1",
            courseId: "Basics",
            timestamp: ISO8601DateFormatter().string(from: existingEvent.timestamp),
            timeZone: "UTC",
            playedSeconds: 600.0,
            isQualifying: true,
            reflection: "Existing reflection"
        )
        let newId = UUID()
        let backupEvent2 = BackupCompletionEvent(
            id: newId.uuidString,
            sessionId: "imported_sess_2",
            courseId: "Managing Anxiety",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            timeZone: "UTC",
            playedSeconds: 900.0,
            isQualifying: true,
            reflection: "New imported reflection"
        )
        
        let doc = MindSpaceBackupDocument(
            stats: BackupStats(totalMindfulMinutes: 25, completedSessionsCount: 2, currentStreak: 2, bestStreak: 2),
            userSettings: BackupUserSettings(defaultDurationMinutes: 15, reminderTime: "09:00", themeMode: "quiet_cosmos", hideStreak: false, compassionPassCount: 2),
            completionEvents: [backupEvent1, backupEvent2],
            favorites: ["local_sess_1", "imported_sess_2"],
            achievements: []
        )
        
        // 3. Apply Merge Import
        try manager.applyImport(document: doc, modelContext: context, isCleanRestore: false)
        
        // 4. Validate that context has exactly 2 records (no duplicates)
        let descriptor = FetchDescriptor<CompletionEvent>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 2, "Merge mode must deduplicate by UUID and preserve existing records.")
        
        let settingsDesc = FetchDescriptor<UserSettings>()
        let updatedSettings = try context.fetch(settingsDesc).first
        XCTAssertEqual(updatedSettings?.reminderTime, "09:00", "Settings should be updated from backup.")
        XCTAssertEqual(updatedSettings?.compassionPassCount, 2, "Compassion passes should be restored.")
    }
    
    func testExportAndImportCleanRestoreModeWipesPreviousState() throws {
        let manager = ProgressTransferManager.shared
        
        let schema = Schema([
            CompletionEvent.self,
            FavoriteItem.self,
            PlaybackResume.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        // 1. Insert 3 old local events
        for i in 1...3 {
            let ev = CompletionEvent(sessionStableId: "old_\(i)", actualPlayedSeconds: 600, isQualifying: true)
            context.insert(ev)
        }
        try context.save()
        
        // 2. Prepare backup with only 1 fresh event
        let freshId = UUID()
        let freshBackup = BackupCompletionEvent(
            id: freshId.uuidString,
            sessionId: "fresh_session",
            courseId: "Foundation",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            timeZone: "UTC",
            playedSeconds: 600.0,
            isQualifying: true,
            reflection: "Clean start"
        )
        let doc = MindSpaceBackupDocument(
            stats: BackupStats(totalMindfulMinutes: 10, completedSessionsCount: 1, currentStreak: 1, bestStreak: 1),
            userSettings: BackupUserSettings(defaultDurationMinutes: 10, reminderTime: "07:00", themeMode: "default", hideStreak: true, compassionPassCount: 0),
            completionEvents: [freshBackup],
            favorites: [],
            achievements: []
        )
        
        // 3. Apply Clean Restore
        try manager.applyImport(document: doc, modelContext: context, isCleanRestore: true)
        
        // 4. Validate that context has only 1 fresh event
        let descriptor = FetchDescriptor<CompletionEvent>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1, "Clean restore must erase previous events and retain only the imported dataset.")
        XCTAssertEqual(fetched.first?.sessionStableId, "fresh_session")
    }
    
    func testUserSettingsMutationsAndPersistence() throws {
        let schema = Schema([UserSettings.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let settings = UserSettings()
        settings.hideStreak = true
        settings.reminderEnabled = true
        settings.reminderTime = "21:30"
        settings.defaultDurationMinutes = 20
        settings.compassionPassCount = 3
        context.insert(settings)
        try context.save()
        
        let fetched = try context.fetch(FetchDescriptor<UserSettings>()).first
        XCTAssertEqual(fetched?.hideStreak, true)
        XCTAssertEqual(fetched?.reminderEnabled, true)
        XCTAssertEqual(fetched?.reminderTime, "21:30")
        XCTAssertEqual(fetched?.defaultDurationMinutes, 20)
        XCTAssertEqual(fetched?.compassionPassCount, 3)
    }
}
