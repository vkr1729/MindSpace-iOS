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
    
    public init(
        backupVersion: Int = 1,
        exportedAt: String = DateFormatterCache.iso8601String(from: Date()),
        appVersion: String = "2.0.0",
        catalogSchemaVersion: Int = 1,
        stats: BackupStats,
        userSettings: BackupUserSettings,
        completionEvents: [BackupCompletionEvent],
        favorites: [String],
        achievements: [BackupAchievement]
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
    public let themeMode: String
    public let hideStreak: Bool
    public let compassionPassCount: Int
    
    public init(
        defaultDurationMinutes: Int,
        reminderTime: String,
        themeMode: String,
        hideStreak: Bool,
        compassionPassCount: Int
    ) {
        self.defaultDurationMinutes = defaultDurationMinutes
        self.reminderTime = reminderTime
        self.themeMode = themeMode
        self.hideStreak = hideStreak
        self.compassionPassCount = compassionPassCount
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

public struct BackupAchievement: Codable, Sendable {
    public let id: String
    public let unlockedAt: String
    
    public init(id: String, unlockedAt: String) {
        self.id = id
        self.unlockedAt = unlockedAt
    }
}
