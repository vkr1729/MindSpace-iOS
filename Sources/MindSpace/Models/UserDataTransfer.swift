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
        appVersion: String = "2.0.0",
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
    
    public init(
        defaultDurationMinutes: Int,
        reminderTime: String,
        reminderEnabled: Bool = false,
        themeMode: String,
        hideStreak: Bool,
        compassionPassCount: Int
    ) {
        self.defaultDurationMinutes = defaultDurationMinutes
        self.reminderTime = reminderTime
        self.reminderEnabled = reminderEnabled
        self.themeMode = themeMode
        self.hideStreak = hideStreak
        self.compassionPassCount = compassionPassCount
    }
    
    // Custom decoding to support legacy backups without reminderEnabled
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.defaultDurationMinutes = try container.decode(Int.self, forKey: .defaultDurationMinutes)
        self.reminderTime = try container.decode(String.self, forKey: .reminderTime)
        self.reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        self.themeMode = try container.decode(String.self, forKey: .themeMode)
        self.hideStreak = try container.decode(Bool.self, forKey: .hideStreak)
        self.compassionPassCount = try container.decode(Int.self, forKey: .compassionPassCount)
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
    public let reflection: String?
    
    public init(
        id: String,
        sessionId: String,
        courseId: String?,
        timestamp: String,
        timeZone: String,
        playedSeconds: Double,
        isQualifying: Bool,
        reflection: String?
    ) {
        self.id = id
        self.sessionId = sessionId
        self.courseId = courseId
        self.timestamp = timestamp
        self.timeZone = timeZone
        self.playedSeconds = playedSeconds
        self.isQualifying = isQualifying
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
    public let updatedAt: String
    
    public init(
        sessionStableId: String,
        relativePath: String,
        sessionTitle: String,
        courseName: String? = nil,
        lastPositionSeconds: Double,
        durationSeconds: Double,
        updatedAt: String = DateFormatterCache.iso8601String(from: Date())
    ) {
        self.sessionStableId = sessionStableId
        self.relativePath = relativePath
        self.sessionTitle = sessionTitle
        self.courseName = courseName
        self.lastPositionSeconds = lastPositionSeconds
        self.durationSeconds = durationSeconds
        self.updatedAt = updatedAt
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

