import Foundation
import SwiftData

/// Handles export and import of `.mindspace` progress JSON documents.
public struct ProgressTransferManager: Sendable {
    public static let shared = ProgressTransferManager()

    public static let supportedBackupVersion = 1
    public static let supportedCatalogSchemaVersion = 1
    public static let maxImportEvents = 100_000
    public static let maxImportFavorites = 20_000
    public static let maxImportResumes = 20_000
    public static let maxPlayedSecondsPerEvent = 24.0 * 60.0 * 60.0

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
    
    public enum ImportError: Error, LocalizedError {
        case unsupportedBackupVersion(Int)
        case unsupportedCatalogSchema(Int)
        case eventLimitExceeded(Int)
        case invalidEvent(String)
        case invalidResume(String)

        public var errorDescription: String? {
            switch self {
            case .unsupportedBackupVersion(let v): return "Unsupported backup version \(v)."
            case .unsupportedCatalogSchema(let v): return "Unsupported catalog schema \(v)."
            case .eventLimitExceeded(let n): return "Backup has too many events (\(n))."
            case .invalidEvent(let reason): return "Invalid backup event: \(reason)."
            case .invalidResume(let reason): return "Invalid backup resume: \(reason)."
            }
        }
    }

    /// Restores or merges imported progress into SwiftData context.
    /// All records are staged and validated before any existing data is touched,
    /// so a corrupt file can never wipe the live database.
    @MainActor
    public func applyImport(
        document: MindSpaceBackupDocument,
        modelContext: ModelContext,
        isCleanRestore: Bool
    ) throws {
        guard document.backupVersion <= Self.supportedBackupVersion else {
            throw ImportError.unsupportedBackupVersion(document.backupVersion)
        }
        guard document.catalogSchemaVersion <= Self.supportedCatalogSchemaVersion else {
            throw ImportError.unsupportedCatalogSchema(document.catalogSchemaVersion)
        }
        guard document.completionEvents.count <= Self.maxImportEvents else {
            throw ImportError.eventLimitExceeded(document.completionEvents.count)
        }
        guard document.favorites.count <= Self.maxImportFavorites else {
            throw ImportError.eventLimitExceeded(document.favorites.count)
        }
        guard (document.resumes ?? []).count <= Self.maxImportResumes else {
            throw ImportError.eventLimitExceeded((document.resumes ?? []).count)
        }

        let stagedEvents = try document.completionEvents.map { try stagedCompletionEvent(from: $0) }
        let stagedResumes = try (document.resumes ?? []).map { try stagedResume(from: $0) }
        let stagedFavorites = document.favorites.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

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
        
        for staged in stagedEvents {
            if !existingIDs.contains(staged.id.uuidString) {
                modelContext.insert(staged.event)
            }
        }

        // Restore Favorites (case-insensitive dedup)
        let favDescriptor = FetchDescriptor<FavoriteItem>()
        let existingFavs = try modelContext.fetch(favDescriptor)
        let existingFavIDs = Set(existingFavs.map { $0.sessionStableId.lowercased() })

        for favID in stagedFavorites {
            if !existingFavIDs.contains(favID.lowercased()) {
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
        if !stagedResumes.isEmpty {
            let resumeDescriptor = FetchDescriptor<PlaybackResume>()
            let existingResumes = try modelContext.fetch(resumeDescriptor)
            var resumeMap = Dictionary(existingResumes.map { ($0.sessionStableId, $0) }, uniquingKeysWith: { first, _ in first })

            for bResume in stagedResumes {
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
        
        // Merge user settings field-by-field. A stale backup must never silently
        // wipe current preferences, onboarding, or disclaimer state.
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let isNewSettings: Bool
        let settings: UserSettings
        if let existing = try modelContext.fetch(settingsDescriptor).first {
            settings = existing
            isNewSettings = false
        } else {
            settings = UserSettings()
            isNewSettings = true
        }
        let incoming = document.userSettings
        if isCleanRestore || isNewSettings {
            settings.defaultDurationMinutes = incoming.defaultDurationMinutes
            settings.reminderTime = incoming.reminderTime
            settings.reminderEnabled = incoming.reminderEnabled
            settings.themeMode = incoming.themeMode
            settings.hideStreak = incoming.hideStreak
            settings.compassionPassCount = incoming.compassionPassCount
        }
        if incoming.hasCompletedOnboarding == true {
            settings.hasCompletedOnboarding = true
        }
        if let goals = incoming.selectedGoals, !goals.isEmpty {
            settings.selectedGoals = goals
        }
        if incoming.hasAcknowledgedDisclaimer == true {
            settings.hasAcknowledgedDisclaimer = true
        }
        if isNewSettings {
            modelContext.insert(settings)
        }

        try modelContext.save()
    }

    /// Validates a backup document without touching SwiftData. Used by tests
    /// and pre-import checks; `applyImport` runs the same gates internally.
    public func stagedValidation(of document: MindSpaceBackupDocument) throws {
        guard document.backupVersion <= Self.supportedBackupVersion else {
            throw ImportError.unsupportedBackupVersion(document.backupVersion)
        }
        guard document.catalogSchemaVersion <= Self.supportedCatalogSchemaVersion else {
            throw ImportError.unsupportedCatalogSchema(document.catalogSchemaVersion)
        }
        guard document.completionEvents.count <= Self.maxImportEvents else {
            throw ImportError.eventLimitExceeded(document.completionEvents.count)
        }
        _ = try document.completionEvents.map { try stagedCompletionEvent(from: $0) }
        _ = try (document.resumes ?? []).map { try stagedResume(from: $0) }
    }

    private func stagedCompletionEvent(from bEvent: BackupCompletionEvent) throws -> (id: UUID, event: CompletionEvent) {
        guard !bEvent.sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.invalidEvent("missing session id")
        }
        guard bEvent.playedSeconds.isFinite,
              bEvent.playedSeconds >= 0,
              bEvent.playedSeconds <= Self.maxPlayedSecondsPerEvent else {
            throw ImportError.invalidEvent("playedSeconds out of range")
        }
        guard let eventDate = DateFormatterCache.dateFromISO8601(bEvent.timestamp) else {
            throw ImportError.invalidEvent("unparseable timestamp")
        }
        let eventTz = TimeZone(identifier: bEvent.timeZone) ?? .current

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
            gmtOffsetSeconds: eventTz.secondsFromGMT(for: eventDate)
        )
        return (eventId, event)
    }

    private func stagedResume(from bResume: BackupPlaybackResume) throws -> BackupPlaybackResume {
        guard !bResume.sessionStableId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.invalidResume("missing session id")
        }
        guard bResume.lastPositionSeconds.isFinite, bResume.lastPositionSeconds >= 0,
              bResume.durationSeconds.isFinite, bResume.durationSeconds >= 0 else {
            throw ImportError.invalidResume("negative position/duration")
        }
        guard DateFormatterCache.dateFromISO8601(bResume.updatedAt) != nil else {
            throw ImportError.invalidResume("unparseable updatedAt")
        }
        return bResume
    }
}
