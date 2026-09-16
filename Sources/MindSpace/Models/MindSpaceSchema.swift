import Foundation
import SwiftData

/// Schema history note: v1.0 shipped without a versioned schema, so the
/// migration baseline starts at v1.1 (the first versioned snapshot). The
/// v1.0-era store is handled by the salvage path in MindSpaceApp, which
/// preserves the old file instead of claiming a recovery.
///
/// Only the CURRENT version's models are versioned snapshots. Older schema
/// versions are intentionally empty: SwiftData computes one CoreData model
/// per schema at launch, and re-registering the same @Model classes under
/// multiple schema versions crashes the host with duplicate version
/// checksums. The lightweight v1.1 -> v1.2 stage is inferred from the
/// current models, so the plan needs just the two version identifiers.

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

public enum MindSpaceSchemaV1_1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 1, 0)
    public static var models: [any PersistentModel.Type] { [] }
}

public enum MindSpaceSchemaV1_2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 2, 0)
    public static var models: [any PersistentModel.Type] {
        [
            CompletionEvent.self,
            PlaybackResume.self,
            FavoriteItem.self,
            UserSettings.self,
            PendingCompletion.self,
        ]
    }
}

public enum MindSpaceMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [MindSpaceSchemaV1_1.self, MindSpaceSchemaV1_2.self]
    }

    public static var stages: [MigrationStage] {
        [
            MigrationStage.lightweight(fromVersion: MindSpaceSchemaV1_1.self, toVersion: MindSpaceSchemaV1_2.self),
        ]
    }
}
