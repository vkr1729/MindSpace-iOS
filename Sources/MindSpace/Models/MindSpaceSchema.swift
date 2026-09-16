import Foundation
import SwiftData

/// Durable outbox for completion writes that failed to persist.
/// Flushed on launch/foreground/background; drained when the event lands.
@Model
public final class PendingCompletion {
    @Attribute(.unique) public var id: UUID = UUID()
    public var sessionStableId: String = ""
    public var courseId: String? = nil
    public var playedSeconds: Double = 0.0
    public var isQualifying: Bool = false
    public var contentType: String = "meditation"
    public var timestamp: Date = Date()
    public var timeZoneIdentifier: String = "UTC"
    public var gmtOffsetSeconds: Int = 0
    public var createdAt: Date = Date()
    public var attempts: Int = 0

    public init(
        id: UUID = UUID(),
        sessionStableId: String,
        courseId: String? = nil,
        playedSeconds: Double,
        isQualifying: Bool,
        contentType: String = "meditation",
        timestamp: Date = Date(),
        timeZoneIdentifier: String = TimeZone.current.identifier,
        gmtOffsetSeconds: Int = TimeZone.current.secondsFromGMT(),
        attempts: Int = 0
    ) {
        self.id = id
        self.sessionStableId = sessionStableId
        self.courseId = courseId
        self.playedSeconds = playedSeconds
        self.isQualifying = isQualifying
        self.contentType = contentType
        self.timestamp = timestamp
        self.timeZoneIdentifier = timeZoneIdentifier
        self.gmtOffsetSeconds = gmtOffsetSeconds
        self.createdAt = Date()
        self.attempts = attempts
    }
}

public enum MindSpaceSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] {
        [CompletionEvent.self, PlaybackResume.self, FavoriteItem.self, UserSettings.self]
    }
}

public enum MindSpaceSchemaV1_1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 1, 0)
    public static var models: [any PersistentModel.Type] {
        [CompletionEvent.self, PlaybackResume.self, FavoriteItem.self, UserSettings.self, PendingCompletion.self]
    }
}

public enum MindSpaceSchemaV1_2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 2, 0)
    public static var models: [any PersistentModel.Type] {
        [CompletionEvent.self, PlaybackResume.self, FavoriteItem.self, UserSettings.self, PendingCompletion.self]
    }
}

public enum MindSpaceMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [MindSpaceSchemaV1.self, MindSpaceSchemaV1_1.self, MindSpaceSchemaV1_2.self]
    }

    public static var stages: [MigrationStage] {
        [
            MigrationStage.lightweight(fromVersion: MindSpaceSchemaV1.self, toVersion: MindSpaceSchemaV1_1.self),
            MigrationStage.lightweight(fromVersion: MindSpaceSchemaV1_1.self, toVersion: MindSpaceSchemaV1_2.self),
        ]
    }
}
