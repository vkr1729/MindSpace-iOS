import Foundation

/// DTO for importing and exporting user data (.mindspace JSON file)
public struct MindSpaceBackupDocument: Codable, Sendable {
    public let backupVersion: Int
    public let exportedAt: String
    public let appVersion: String
    public let catalogSchemaVersion: Int
    public let stats: BackupStats
    public let userSettings: BackupUserSettings
    public let completionEvents: [BackupCompletionEvent]
    public let favorites: [String]
    public let achievements: [BackupAchievement]
    public let resumes: [BackupPlaybackResume]?
    
    public init(
        backupVersion: Int = 1,
        exportedAt: String = DateFormatterCache.iso8601String(from: Date()),
        appVersion: String = "2.4.0",
        catalogSchemaVersion: Int = 1,
        stats: BackupStats,
        userSettings: BackupUserSettings,
        completionEvents: [BackupCompletionEvent],
        favorites: [String],
        achievements: [BackupAchievement],
        resumes: [BackupPlaybackResume]? = nil
    ) {
        self.backupVersion = backupVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.catalogSchemaVersion = catalogSchemaVersion
        self.stats = stats
        self.userSettings = userSettings
        self.completionEvents = completionEvents
        self.favorites = favorites
        self.achievements = achievements
        self.resumes = resumes
    }
}

public struct BackupStats: Codable, Sendable {
    public let totalMindfulMinutes: Int
    public let completedSessionsCount: Int
    public let currentStreak: Int
    public let bestStreak: Int
    
    public init(totalMindfulMinutes: Int, completedSessionsCount: Int, currentStreak: Int, bestStreak: Int) {
        self.totalMindfulMinutes = totalMindfulMinutes
        self.completedSessionsCount = completedSessionsCount
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }
}

public struct BackupUserSettings: Codable, Sendable {
    public let defaultDurationMinutes: Int
    public let reminderTime: String
    public let reminderEnabled: Bool
    public let themeMode: String
    public let hideStreak: Bool
    public let compassionPassCount: Int
    public let hasCompletedOnboarding: Bool?
    public let selectedGoals: [String]?
    public let hasAcknowledgedDisclaimer: Bool?
    
    public init(
        defaultDurationMinutes: Int,
        reminderTime: String,
        reminderEnabled: Bool = false,
        themeMode: String,
        hideStreak: Bool,
        compassionPassCount: Int,
        hasCompletedOnboarding: Bool? = true,
        selectedGoals: [String]? = nil,
        hasAcknowledgedDisclaimer: Bool? = true
    ) {
        self.defaultDurationMinutes = defaultDurationMinutes
        self.reminderTime = reminderTime
        self.reminderEnabled = reminderEnabled
        self.themeMode = themeMode
        self.hideStreak = hideStreak
        self.compassionPassCount = compassionPassCount
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.selectedGoals = selectedGoals
        self.hasAcknowledgedDisclaimer = hasAcknowledgedDisclaimer
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.defaultDurationMinutes = try container.decode(Int.self, forKey: .defaultDurationMinutes)
        self.reminderTime = try container.decode(String.self, forKey: .reminderTime)
        self.reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        self.themeMode = try container.decode(String.self, forKey: .themeMode)
        self.hideStreak = try container.decode(Bool.self, forKey: .hideStreak)
        self.compassionPassCount = try container.decode(Int.self, forKey: .compassionPassCount)
        self.hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)
        self.selectedGoals = try container.decodeIfPresent([String].self, forKey: .selectedGoals)
        self.hasAcknowledgedDisclaimer = try container.decodeIfPresent(Bool.self, forKey: .hasAcknowledgedDisclaimer)
    }
}

public struct BackupCompletionEvent: Codable, Sendable {
    public let id: String
    public let sessionId: String
    public let courseId: String?
    public let timestamp: String
    public let timeZone: String
    public let playedSeconds: Double
    public let isQualifying: Bool
    public let contentType: String?
    public let reflection: String?
    
    public init(
        id: String,
        sessionId: String,
        courseId: String?,
        timestamp: String,
        timeZone: String,
        playedSeconds: Double,
        isQualifying: Bool,
        contentType: String? = "meditation",
        reflection: String?
    ) {
        self.id = id
        self.sessionId = sessionId
        self.courseId = courseId
        self.timestamp = timestamp
        self.timeZone = timeZone
        self.playedSeconds = playedSeconds
        self.isQualifying = isQualifying
        self.contentType = contentType
        self.reflection = reflection
    }
}

public struct BackupPlaybackResume: Codable, Sendable {
    public let sessionStableId: String
    public let relativePath: String
    public let sessionTitle: String
    public let courseName: String?
    public let lastPositionSeconds: Double
    public let durationSeconds: Double
    public let accumulatedListenedSeconds: Double?
    public let updatedAt: String
    public let contentType: String?
    public let dayNumber: Int?
    public let videoAttachmentPath: String?

    public init(
        sessionStableId: String,
        relativePath: String,
        sessionTitle: String,
        courseName: String? = nil,
        lastPositionSeconds: Double,
        durationSeconds: Double,
        accumulatedListenedSeconds: Double? = 0.0,
        updatedAt: String = DateFormatterCache.iso8601String(from: Date()),
        contentType: String? = nil,
        dayNumber: Int? = nil,
        videoAttachmentPath: String? = nil
    ) {
        self.sessionStableId = sessionStableId
        self.relativePath = relativePath
        self.sessionTitle = sessionTitle
        self.courseName = courseName
        self.lastPositionSeconds = lastPositionSeconds
        self.durationSeconds = durationSeconds
        self.accumulatedListenedSeconds = accumulatedListenedSeconds
        self.updatedAt = updatedAt
        self.contentType = contentType
        self.dayNumber = dayNumber
        self.videoAttachmentPath = videoAttachmentPath
    }

    private enum CodingKeys: String, CodingKey {
        case sessionStableId, relativePath, sessionTitle, courseName
        case lastPositionSeconds, durationSeconds, accumulatedListenedSeconds
        case updatedAt, contentType, dayNumber, videoAttachmentPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sessionStableId = try container.decode(String.self, forKey: .sessionStableId)
        self.relativePath = try container.decode(String.self, forKey: .relativePath)
        self.sessionTitle = try container.decode(String.self, forKey: .sessionTitle)
        self.courseName = try container.decodeIfPresent(String.self, forKey: .courseName)
        self.lastPositionSeconds = try container.decode(Double.self, forKey: .lastPositionSeconds)
        self.durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        self.accumulatedListenedSeconds = try container.decodeIfPresent(Double.self, forKey: .accumulatedListenedSeconds)
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
        self.contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        self.dayNumber = try container.decodeIfPresent(Int.self, forKey: .dayNumber)
        self.videoAttachmentPath = try container.decodeIfPresent(String.self, forKey: .videoAttachmentPath)
    }
}

public struct BackupAchievement: Codable, Sendable {
    public let id: String
    public let unlockedAt: String
    
    public init(id: String, unlockedAt: String) {
        self.id = id
        self.unlockedAt = unlockedAt
    }
}
