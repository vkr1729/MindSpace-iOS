import Foundation
import SwiftData

/// Handles export and import of `.mindspace` progress JSON documents.
public struct ProgressTransferManager: Sendable {
    public static let shared = ProgressTransferManager()
    
    public init() {}
    
    /// Generates a complete .mindspace backup document from current SwiftData state.
    public func createBackupDocument(
        events: [CompletionEvent],
        favorites: [FavoriteItem],
        settings: UserSettings,
        orbitStats: OrbitStats
    ) -> MindSpaceBackupDocument {
        let backupEvents = events.map { e in
            BackupCompletionEvent(
                id: e.id.uuidString,
                sessionId: e.sessionStableId,
                courseId: e.courseId,
                timestamp: DateFormatterCache.iso8601String(from: e.timestamp),
                timeZone: e.timeZoneIdentifier,
                playedSeconds: e.actualPlayedSeconds,
                isQualifying: e.isQualifyingMeditation,
                reflection: e.reflectionNote
            )
        }
        
        let favIDs = favorites.map { $0.sessionStableId }
        
        let stats = BackupStats(
            totalMindfulMinutes: orbitStats.totalMindfulMinutes,
            completedSessionsCount: orbitStats.completedSessionsCount,
            currentStreak: orbitStats.currentStreak,
            bestStreak: orbitStats.bestStreak
        )
        
        let backupSettings = BackupUserSettings(
            defaultDurationMinutes: settings.defaultDurationMinutes,
            reminderTime: settings.reminderTime,
            themeMode: settings.themeMode,
            hideStreak: settings.hideStreak,
            compassionPassCount: settings.compassionPassCount
        )
        
        let achievements = OrbitCalculator().getAchievements(
            currentStreak: orbitStats.currentStreak,
            totalSessions: orbitStats.completedSessionsCount
        ).filter { $0.isUnlocked }.map {
            BackupAchievement(id: $0.id, unlockedAt: DateFormatterCache.iso8601String(from: Date()))
        }
        
        return MindSpaceBackupDocument(
            stats: stats,
            userSettings: backupSettings,
            completionEvents: backupEvents,
            favorites: favIDs,
            achievements: achievements
        )
    }
    
    /// Exports backup document to a local JSON file in temporary directory for sharing.
    public func exportToFile(document: MindSpaceBackupDocument) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        
        let timestamp = DateFormatterCache.backupTimestampString()
        let fileName = "MindSpace-Backup-\(timestamp).mindspace"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        return tempURL
    }
    
    /// Parses and validates incoming .mindspace file data.
    public func parseBackupDocument(from url: URL) throws -> MindSpaceBackupDocument {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(MindSpaceBackupDocument.self, from: data)
    }
    
    /// Restores or merges imported progress into SwiftData context.
    public func applyImport(
        document: MindSpaceBackupDocument,
        modelContext: ModelContext,
        isCleanRestore: Bool
    ) throws {
        if isCleanRestore {
            // Delete all existing events and favorites
            try modelContext.delete(model: CompletionEvent.self)
            try modelContext.delete(model: FavoriteItem.self)
            try modelContext.delete(model: PlaybackResume.self)
        }
        
        // Fetch existing event IDs if merging
        let existingDescriptor = FetchDescriptor<CompletionEvent>()
        let existingEvents = try modelContext.fetch(existingDescriptor)
        let existingIDs = Set(existingEvents.map { $0.id.uuidString })
        
        for bEvent in document.completionEvents {
            if !existingIDs.contains(bEvent.id) {
                let eventDate = DateFormatterCache.dateFromISO8601(bEvent.timestamp) ?? Date()
                let event = CompletionEvent(
                    sessionStableId: bEvent.sessionId,
                    courseId: bEvent.courseId,
                    actualPlayedSeconds: bEvent.playedSeconds,
                    isQualifying: bEvent.isQualifying,
                    reflection: bEvent.reflection,
                    timestamp: eventDate
                )
                if let uuid = UUID(uuidString: bEvent.id) {
                    event.id = uuid
                }
                modelContext.insert(event)
            }
        }
        
        // Update user settings
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let settings = (try modelContext.fetch(settingsDescriptor)).first ?? UserSettings()
        settings.defaultDurationMinutes = document.userSettings.defaultDurationMinutes
        settings.reminderTime = document.userSettings.reminderTime
        settings.themeMode = document.userSettings.themeMode
        settings.hideStreak = document.userSettings.hideStreak
        settings.compassionPassCount = document.userSettings.compassionPassCount
        modelContext.insert(settings)
        
        try modelContext.save()
    }
}
