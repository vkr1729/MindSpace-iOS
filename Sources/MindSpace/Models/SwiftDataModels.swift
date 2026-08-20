import Foundation
import SwiftData

/// Append-only log of completed mindful meditations and listening events.
@Model
public final class CompletionEvent {
    @Attribute(.unique) public var id: UUID = UUID()
    public var sessionStableId: String = ""
    public var courseId: String? = nil
    public var timestamp: Date = Date()
    public var timeZoneIdentifier: String = "UTC"
    public var gmtOffsetSeconds: Int = 0
    public var actualPlayedSeconds: Double = 0.0
    public var isQualifyingMeditation: Bool = false
    public var contentType: String = "meditation" // "meditation", "sleep", "video", "sos", "sensitive"
    public var reflectionNote: String? = nil // "lighter", "same", "heavier"
    
    public init(
        id: UUID = UUID(),
        sessionStableId: String,
        courseId: String? = nil,
        actualPlayedSeconds: Double,
        isQualifying: Bool,
        contentType: String = "meditation",
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
        self.contentType = contentType
        self.reflectionNote = reflection
    }
}

/// Resume point storing relative media path, playback progress, and verified listened time.
@Model
public final class PlaybackResume {
    @Attribute(.unique) public var sessionStableId: String = ""
    public var relativePath: String = ""
    public var sessionTitle: String = ""
    public var courseName: String? = nil
    public var lastPositionSeconds: Double = 0.0
    public var durationSeconds: Double = 0.0
    public var accumulatedListenedSeconds: Double = 0.0
    public var updatedAt: Date = Date()
    
    public init(
        sessionStableId: String,
        relativePath: String,
        sessionTitle: String,
        courseName: String? = nil,
        position: Double,
        duration: Double,
        accumulatedListenedSeconds: Double = 0.0
    ) {
        self.sessionStableId = sessionStableId
        self.relativePath = relativePath
        self.sessionTitle = sessionTitle
        self.courseName = courseName
        self.lastPositionSeconds = position
        self.durationSeconds = duration
        self.accumulatedListenedSeconds = accumulatedListenedSeconds
        self.updatedAt = Date()
    }
}

/// User favorite session pointer.
@Model
public final class FavoriteItem {
    @Attribute(.unique) public var sessionStableId: String = ""
    public var title: String = ""
    public var relativePath: String = ""
    public var addedAt: Date = Date()
    
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
    @Attribute(.unique) public var id: String = "primary_settings"
    public var defaultDurationMinutes: Int = 10
    public var reminderTime: String = "08:00" // e.g. "08:00"
    public var reminderEnabled: Bool = false
    public var themeMode: String = "quiet_cosmos" // "quiet_cosmos" or "sleep_abyss"
    public var hideStreak: Bool = false
    public var compassionPassCount: Int = 0
    public var lastUsedCompassionPassDate: Date? = nil
    public var hasCompletedOnboarding: Bool = false
    public var selectedGoalsCSV: String = "" // Comma-separated list of goal IDs
    public var hasAcknowledgedDisclaimer: Bool = false
    
    public init(
        id: String = "primary_settings",
        defaultDuration: Int = 10,
        reminderTime: String = "08:00",
        reminderEnabled: Bool = false,
        themeMode: String = "quiet_cosmos",
        hideStreak: Bool = false,
        compassionPassCount: Int = 0,
        lastUsedCompassionPassDate: Date? = nil,
        hasCompletedOnboarding: Bool = false,
        selectedGoals: [String] = [],
        hasAcknowledgedDisclaimer: Bool = false
    ) {
        self.id = id
        self.defaultDurationMinutes = defaultDuration
        self.reminderTime = reminderTime
        self.reminderEnabled = reminderEnabled
        self.themeMode = themeMode
        self.hideStreak = hideStreak
        self.compassionPassCount = compassionPassCount
        self.lastUsedCompassionPassDate = lastUsedCompassionPassDate
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.selectedGoalsCSV = selectedGoals.joined(separator: ",")
        self.hasAcknowledgedDisclaimer = hasAcknowledgedDisclaimer
    }
    
    public var selectedGoals: [String] {
        get {
            selectedGoalsCSV.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        set {
            selectedGoalsCSV = newValue.joined(separator: ",")
        }
    }
}
