import Foundation
import SwiftData

/// Thread-safe SwiftData actor isolating progression and playback state mutations.
@ModelActor
public actor ProgressActor {
    
    // MARK: - Completion Events

    public func hasCompletion(id: UUID) throws -> Bool {
        let descriptor = FetchDescriptor<CompletionEvent>(
            predicate: #Predicate { $0.id == id }
        )
        return try !modelContext.fetch(descriptor).isEmpty
    }

    public func enqueuePendingCompletion(
        id: UUID,
        sessionStableId: String,
        courseId: String?,
        playedSeconds: Double,
        isQualifying: Bool,
        contentType: String,
        timestamp: Date,
        timeZoneIdentifier: String,
        gmtOffsetSeconds: Int
    ) throws {
        let entry = PendingCompletion(
            id: id,
            sessionStableId: sessionStableId,
            courseId: courseId,
            playedSeconds: playedSeconds,
            isQualifying: isQualifying,
            contentType: contentType,
            timestamp: timestamp,
            timeZoneIdentifier: timeZoneIdentifier,
            gmtOffsetSeconds: gmtOffsetSeconds
        )
        modelContext.insert(entry)
        try modelContext.save()
    }

    /// Replays queued completions into the event log. Returns the number
    /// of entries still pending (failed again or skipped as duplicates).
    @discardableResult
    public func flushPendingCompletions() throws -> Int {
        let descriptor = FetchDescriptor<PendingCompletion>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let pending = try modelContext.fetch(descriptor)
        var remaining = 0
        for entry in pending {
            entry.attempts += 1
            do {
                let eventId = entry.id
                let existing = FetchDescriptor<CompletionEvent>(
                    predicate: #Predicate { $0.id == eventId }
                )
                if try modelContext.fetch(existing).isEmpty {
                    let event = CompletionEvent(
                        id: entry.id,
                        sessionStableId: entry.sessionStableId,
                        courseId: entry.courseId,
                        actualPlayedSeconds: entry.playedSeconds,
                        isQualifying: entry.isQualifying,
                        contentType: entry.contentType,
                        timestamp: entry.timestamp,
                        timeZoneIdentifier: entry.timeZoneIdentifier,
                        gmtOffsetSeconds: entry.gmtOffsetSeconds
                    )
                    modelContext.insert(event)
                }
                modelContext.delete(entry)
                try modelContext.save()
            } catch {
                remaining += 1
                try? modelContext.save()
            }
        }
        return remaining
    }

    public func pendingCompletionCount() throws -> Int {
        try modelContext.fetch(FetchDescriptor<PendingCompletion>()).count
    }

    @discardableResult
    public func recordCompletion(
        id: UUID = UUID(),
        sessionStableId: String,
        courseId: String? = nil,
        playedSeconds: Double,
        isQualifying: Bool,
        contentType: String = "meditation",
        reflection: String? = nil,
        timestamp: Date = Date(),
        timeZoneIdentifier: String = TimeZone.current.identifier,
        gmtOffsetSeconds: Int = TimeZone.current.secondsFromGMT()
    ) throws -> UUID {
        let event = CompletionEvent(
            id: id,
            sessionStableId: sessionStableId,
            courseId: courseId,
            actualPlayedSeconds: playedSeconds,
            isQualifying: isQualifying,
            contentType: contentType,
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
        duration: Double,
        accumulatedListenedSeconds: Double = 0.0
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
            existing.accumulatedListenedSeconds = accumulatedListenedSeconds
            existing.updatedAt = Date()
        } else {
            let newResume = PlaybackResume(
                sessionStableId: sessionStableId,
                relativePath: relativePath,
                sessionTitle: title,
                courseName: courseName,
                position: position,
                duration: duration,
                accumulatedListenedSeconds: accumulatedListenedSeconds
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
        compassionPassCount: Int? = nil,
        lastUsedCompassionPassDate: Date? = nil,
        hasCompletedOnboarding: Bool? = nil,
        selectedGoals: [String]? = nil,
        hasAcknowledgedDisclaimer: Bool? = nil
    ) throws {
        let settings = try getOrCreateSettings()
        if let defaultDuration { settings.defaultDurationMinutes = defaultDuration }
        if let reminderTime { settings.reminderTime = reminderTime }
        if let reminderEnabled { settings.reminderEnabled = reminderEnabled }
        if let themeMode { settings.themeMode = themeMode }
        if let hideStreak { settings.hideStreak = hideStreak }
        if let compassionPassCount { settings.compassionPassCount = compassionPassCount }
        if let lastUsedCompassionPassDate { settings.lastUsedCompassionPassDate = lastUsedCompassionPassDate }
        if let hasCompletedOnboarding { settings.hasCompletedOnboarding = hasCompletedOnboarding }
        if let selectedGoals { settings.selectedGoals = selectedGoals }
        if let hasAcknowledgedDisclaimer { settings.hasAcknowledgedDisclaimer = hasAcknowledgedDisclaimer }
        try modelContext.save()
    }
}
