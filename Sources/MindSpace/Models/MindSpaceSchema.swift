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
