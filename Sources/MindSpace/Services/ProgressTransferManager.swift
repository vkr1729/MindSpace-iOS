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
        orbitStats: OrbitStats,
        resumes: [PlaybackResume] = []
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
                contentType: e.contentType,
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
            reminderEnabled: settings.reminderEnabled,
            themeMode: settings.themeMode,
            hideStreak: settings.hideStreak,
            compassionPassCount: settings.compassionPassCount,
            hasCompletedOnboarding: settings.hasCompletedOnboarding,
            selectedGoals: settings.selectedGoals,
            hasAcknowledgedDisclaimer: settings.hasAcknowledgedDisclaimer
        )
        
        let achievements = OrbitCalculator().getAchievements(
            currentStreak: orbitStats.currentStreak,
            totalSessions: orbitStats.completedSessionsCount
        ).filter { $0.isUnlocked }.map {
            BackupAchievement(id: $0.id, unlockedAt: DateFormatterCache.iso8601String(from: Date()))
        }
        
        let backupResumes = resumes.map { r in
            BackupPlaybackResume(
                sessionStableId: r.sessionStableId,
                relativePath: r.relativePath,
                sessionTitle: r.sessionTitle,
                courseName: r.courseName,
                lastPositionSeconds: r.lastPositionSeconds,
                durationSeconds: r.durationSeconds,
                accumulatedListenedSeconds: r.accumulatedListenedSeconds,
                updatedAt: DateFormatterCache.iso8601String(from: r.updatedAt)
            )
        }
        
        return MindSpaceBackupDocument(
            stats: stats,
            userSettings: backupSettings,
            completionEvents: backupEvents,
            favorites: favIDs,
            achievements: achievements,
            resumes: backupResumes
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
    @MainActor
    public func applyImport(
        document: MindSpaceBackupDocument,
        modelContext: ModelContext,
        isCleanRestore: Bool
    ) throws {
        if isCleanRestore {
            // Delete all existing events, favorites, and resumes
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
                let eventTz = TimeZone(identifier: bEvent.timeZone) ?? .current
                let gmtOffset = eventTz.secondsFromGMT(for: eventDate)
                
                let eventId = UUID(uuidString: bEvent.id) ?? UUID()
                let event = CompletionEvent(
                    id: eventId,
                    sessionStableId: bEvent.sessionId,
                    courseId: bEvent.courseId,
                    actualPlayedSeconds: bEvent.playedSeconds,
                    isQualifying: bEvent.isQualifying,
                    contentType: bEvent.contentType ?? "meditation",
                    reflection: bEvent.reflection,
                    timestamp: eventDate,
                    timeZoneIdentifier: bEvent.timeZone,
                    gmtOffsetSeconds: gmtOffset
                )
                modelContext.insert(event)
            }
        }
        
        // Restore Favorites
        let favDescriptor = FetchDescriptor<FavoriteItem>()
        let existingFavs = try modelContext.fetch(favDescriptor)
        let existingFavIDs = Set(existingFavs.map { $0.sessionStableId })
        
        for favID in document.favorites {
            if !existingFavIDs.contains(favID) {
                // Resolve title from catalog if possible
                let single = CatalogService.shared.getSingleSession(by: favID)
                let session = CatalogService.shared.getSession(by: favID)
                let course = CatalogService.shared.getCourse(by: favID)
                
                let title = single?.title ?? session?.title ?? course?.name ?? favID
                let relPath = single?.relativePath ?? session?.relativePath ?? course?.folderName ?? ""
                
                let favItem = FavoriteItem(sessionStableId: favID, title: title, relativePath: relPath)
                modelContext.insert(favItem)
            }
        }
        
        // Restore Resumes if present
        if let docResumes = document.resumes {
            let resumeDescriptor = FetchDescriptor<PlaybackResume>()
            let existingResumes = try modelContext.fetch(resumeDescriptor)
            var resumeMap = Dictionary(uniqueKeysWithValues: existingResumes.map { ($0.sessionStableId, $0) })
            
            for bResume in docResumes {
                let accSecs = bResume.accumulatedListenedSeconds ?? 0.0
                if let existing = resumeMap[bResume.sessionStableId] {
                    existing.relativePath = bResume.relativePath
                    existing.sessionTitle = bResume.sessionTitle
                    existing.courseName = bResume.courseName
                    existing.lastPositionSeconds = bResume.lastPositionSeconds
                    existing.durationSeconds = bResume.durationSeconds
                    existing.accumulatedListenedSeconds = accSecs
                    if let updatedDate = DateFormatterCache.dateFromISO8601(bResume.updatedAt) {
                        existing.updatedAt = updatedDate
                    }
                } else {
                    let resume = PlaybackResume(
                        sessionStableId: bResume.sessionStableId,
                        relativePath: bResume.relativePath,
                        sessionTitle: bResume.sessionTitle,
                        courseName: bResume.courseName,
                        position: bResume.lastPositionSeconds,
                        duration: bResume.durationSeconds,
                        accumulatedListenedSeconds: accSecs
                    )
                    if let updatedDate = DateFormatterCache.dateFromISO8601(bResume.updatedAt) {
                        resume.updatedAt = updatedDate
                    }
                    modelContext.insert(resume)
                    resumeMap[bResume.sessionStableId] = resume
                }
            }
        }
        
        // Update user settings
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let settings = (try modelContext.fetch(settingsDescriptor)).first ?? UserSettings()
        settings.defaultDurationMinutes = document.userSettings.defaultDurationMinutes
        settings.reminderTime = document.userSettings.reminderTime
        settings.reminderEnabled = document.userSettings.reminderEnabled
        settings.themeMode = document.userSettings.themeMode
        settings.hideStreak = document.userSettings.hideStreak
        settings.compassionPassCount = document.userSettings.compassionPassCount
        if let onb = document.userSettings.hasCompletedOnboarding {
            settings.hasCompletedOnboarding = onb
        }
        if let goals = document.userSettings.selectedGoals {
            settings.selectedGoals = goals
        }
        if let ack = document.userSettings.hasAcknowledgedDisclaimer {
            settings.hasAcknowledgedDisclaimer = ack
        }
        modelContext.insert(settings)
        
        try modelContext.save()
    }
}
