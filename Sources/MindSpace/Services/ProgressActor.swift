import Foundation
import SwiftData

/// Thread-safe SwiftData actor isolating progression and playback state mutations.
@ModelActor
public actor ProgressActor {
    
    // MARK: - Completion Events
    
    @discardableResult
    public func recordCompletion(
        sessionStableId: String,
        courseId: String? = nil,
        playedSeconds: Double,
        isQualifying: Bool,
        reflection: String? = nil,
        timestamp: Date = Date(),
        timeZoneIdentifier: String = TimeZone.current.identifier,
        gmtOffsetSeconds: Int = TimeZone.current.secondsFromGMT()
    ) throws -> UUID {
        let event = CompletionEvent(
            sessionStableId: sessionStableId,
            courseId: courseId,
            actualPlayedSeconds: playedSeconds,
            isQualifying: isQualifying,
            reflection: reflection,
            timestamp: timestamp,
            timeZoneIdentifier: timeZoneIdentifier,
            gmtOffsetSeconds: gmtOffsetSeconds
        )
        modelContext.insert(event)
        try modelContext.save()
        return event.id
    }
    
    public func saveReflection(for completionId: UUID, note: String) throws {
        let descriptor = FetchDescriptor<CompletionEvent>(
            predicate: #Predicate { $0.id == completionId }
        )
        let matches = try modelContext.fetch(descriptor)
        if let event = matches.first {
            event.reflectionNote = note
            try modelContext.save()
        }
    }
    
    public func fetchAllCompletionEvents() throws -> [CompletionEvent] {
        let descriptor = FetchDescriptor<CompletionEvent>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    public func fetchCompletedSessionIDs() throws -> Set<String> {
        let events = try fetchAllCompletionEvents()
        return Set(events.filter { $0.isQualifyingMeditation }.map { $0.sessionStableId })
    }
    
    // MARK: - Playback Resume
    
    public func updateResumePosition(
        sessionStableId: String,
        relativePath: String,
        title: String,
        courseName: String?,
        position: Double,
        duration: Double
    ) throws {
        let descriptor = FetchDescriptor<PlaybackResume>(
            predicate: #Predicate { $0.sessionStableId == sessionStableId }
        )
        let matches = try modelContext.fetch(descriptor)
        if let existing = matches.first {
            existing.relativePath = relativePath
            existing.sessionTitle = title
            existing.courseName = courseName
            existing.lastPositionSeconds = position
            existing.durationSeconds = duration
            existing.updatedAt = Date()
        } else {
            let newResume = PlaybackResume(
                sessionStableId: sessionStableId,
                relativePath: relativePath,
                sessionTitle: title,
                courseName: courseName,
                position: position,
                duration: duration
            )
            modelContext.insert(newResume)
        }
        try modelContext.save()
    }
    
    public func deleteResume(sessionStableId: String) throws {
        let descriptor = FetchDescriptor<PlaybackResume>(
            predicate: #Predicate { $0.sessionStableId == sessionStableId }
        )
        let matches = try modelContext.fetch(descriptor)
        for match in matches {
            modelContext.delete(match)
        }
        if !matches.isEmpty {
            try modelContext.save()
        }
    }
    
    public func fetchResume(for sessionStableId: String) throws -> PlaybackResume? {
        let descriptor = FetchDescriptor<PlaybackResume>(
            predicate: #Predicate { $0.sessionStableId == sessionStableId }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    public func fetchLatestResume() throws -> PlaybackResume? {
        var descriptor = FetchDescriptor<PlaybackResume>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
    
    // MARK: - Favorites
    
    public func toggleFavorite(sessionStableId: String, title: String, relativePath: String) throws -> Bool {
        let descriptor = FetchDescriptor<FavoriteItem>(
            predicate: #Predicate { $0.sessionStableId == sessionStableId }
        )
        let matches = try modelContext.fetch(descriptor)
        if let existing = matches.first {
            modelContext.delete(existing)
            try modelContext.save()
            return false
        } else {
            let fav = FavoriteItem(sessionStableId: sessionStableId, title: title, relativePath: relativePath)
            modelContext.insert(fav)
            try modelContext.save()
            return true
        }
    }
    
    public func isFavorite(sessionStableId: String) throws -> Bool {
        let descriptor = FetchDescriptor<FavoriteItem>(
            predicate: #Predicate { $0.sessionStableId == sessionStableId }
        )
        return try !modelContext.fetch(descriptor).isEmpty
    }
    
    public func fetchAllFavorites() throws -> [FavoriteItem] {
        let descriptor = FetchDescriptor<FavoriteItem>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - User Settings
    
    public func getOrCreateSettings() throws -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        let matches = try modelContext.fetch(descriptor)
        if let settings = matches.first {
            return settings
        }
        let initial = UserSettings()
        modelContext.insert(initial)
        try modelContext.save()
        return initial
    }
    
    public func updateSettings(
        defaultDuration: Int? = nil,
        reminderTime: String? = nil,
        reminderEnabled: Bool? = nil,
        themeMode: String? = nil,
        hideStreak: Bool? = nil,
        compassionPassCount: Int? = nil
    ) throws {
        let settings = try getOrCreateSettings()
        if let defaultDuration { settings.defaultDurationMinutes = defaultDuration }
        if let reminderTime { settings.reminderTime = reminderTime }
        if let reminderEnabled { settings.reminderEnabled = reminderEnabled }
        if let themeMode { settings.themeMode = themeMode }
        if let hideStreak { settings.hideStreak = hideStreak }
        if let compassionPassCount { settings.compassionPassCount = compassionPassCount }
        try modelContext.save()
    }
}
