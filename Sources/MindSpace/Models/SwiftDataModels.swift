import Foundation
import SwiftData

/// Append-only log of completed mindful meditations.
@Model
public final class CompletionEvent {
    @Attribute(.unique) public var id: UUID
    public var sessionStableId: String
    public var courseId: String?
    public var timestamp: Date
    public var timeZoneIdentifier: String
    public var gmtOffsetSeconds: Int
    public var actualPlayedSeconds: Double
    public var isQualifyingMeditation: Bool
    public var reflectionNote: String? // "lighter", "same", "heavier"
    
    public init(
        id: UUID = UUID(),
        sessionStableId: String,
        courseId: String? = nil,
        actualPlayedSeconds: Double,
        isQualifying: Bool,
        reflection: String? = nil,
        timestamp: Date = Date(),
        timeZoneIdentifier: String = TimeZone.current.identifier,
        gmtOffsetSeconds: Int = TimeZone.current.secondsFromGMT()
    ) {
        self.id = id
        self.sessionStableId = sessionStableId
        self.courseId = courseId
        self.timestamp = timestamp
        self.timeZoneIdentifier = timeZoneIdentifier
        self.gmtOffsetSeconds = gmtOffsetSeconds
        self.actualPlayedSeconds = actualPlayedSeconds
        self.isQualifyingMeditation = isQualifying
        self.reflectionNote = reflection
    }
}

/// Resume point storing relative media path and playback progress.
@Model
public final class PlaybackResume {
    @Attribute(.unique) public var sessionStableId: String
    public var relativePath: String
    public var sessionTitle: String
    public var courseName: String?
    public var lastPositionSeconds: Double
    public var durationSeconds: Double
    public var updatedAt: Date
    
    public init(
        sessionStableId: String,
        relativePath: String,
        sessionTitle: String,
        courseName: String? = nil,
        position: Double,
        duration: Double
    ) {
        self.sessionStableId = sessionStableId
        self.relativePath = relativePath
        self.sessionTitle = sessionTitle
        self.courseName = courseName
        self.lastPositionSeconds = position
        self.durationSeconds = duration
        self.updatedAt = Date()
    }
}

/// User favorite session pointer.
@Model
public final class FavoriteItem {
    @Attribute(.unique) public var sessionStableId: String
    public var title: String
    public var relativePath: String
    public var addedAt: Date
    
    public init(sessionStableId: String, title: String, relativePath: String) {
        self.sessionStableId = sessionStableId
        self.title = title
        self.relativePath = relativePath
        self.addedAt = Date()
    }
}

/// User preferences and persistent local settings.
@Model
public final class UserSettings {
    @Attribute(.unique) public var id: String
    public var defaultDurationMinutes: Int
    public var reminderTime: String // e.g. "08:00"
    public var reminderEnabled: Bool
    public var themeMode: String // "quiet_cosmos" or "sleep_abyss"
    public var hideStreak: Bool
    public var compassionPassCount: Int
    public var lastUsedCompassionPassDate: Date?
    
    public init(
        id: String = "primary_settings",
        defaultDuration: Int = 10,
        reminderTime: String = "08:00",
        reminderEnabled: Bool = false,
        themeMode: String = "quiet_cosmos",
        hideStreak: Bool = false,
        compassionPassCount: Int = 0,
        lastUsedCompassionPassDate: Date? = nil
    ) {
        self.id = id
        self.defaultDurationMinutes = defaultDuration
        self.reminderTime = reminderTime
        self.reminderEnabled = reminderEnabled
        self.themeMode = themeMode
        self.hideStreak = hideStreak
        self.compassionPassCount = compassionPassCount
        self.lastUsedCompassionPassDate = lastUsedCompassionPassDate
    }
}
