import XCTest
import Foundation
import SwiftData
@testable import MindSpace

final class P1Batch2RemediationTests: XCTestCase {

    private func batch2Schema() -> Schema {
        Schema(versionedSchema: MindSpaceSchemaV1_1.self)
    }

    private func inMemoryContainer() throws -> ModelContainer {
        let schema = batch2Schema()
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - P1-1: versioned schema + migration plan

    func testP1_1_MigrationPlanCoversV1ToV1_1() {
        XCTAssertEqual(MindSpaceMigrationPlan.schemas.count, 2)
        XCTAssertEqual(
            MindSpaceSchemaV1.versionIdentifier,
            Schema.Version(1, 0, 0)
        )
        XCTAssertEqual(
            MindSpaceSchemaV1_1.versionIdentifier,
            Schema.Version(1, 1, 0)
        )
        XCTAssertFalse(MindSpaceMigrationPlan.stages.isEmpty, "Plan must define the v1 -> v1.1 stage.")
        let v1ModelNames = MindSpaceSchemaV1.models.map { String(describing: $0) }
        XCTAssertEqual(v1ModelNames.count, 4)
        let v11ModelNames = MindSpaceSchemaV1_1.models.map { String(describing: $0) }
        XCTAssertTrue(
            v11ModelNames.contains { $0.contains("PendingCompletion") },
            "v1.1 must carry the outbox entity."
        )
        XCTAssertTrue(
            v11ModelNames.contains { $0.contains("CompletionEvent") },
            "v1.1 must keep the event log."
        )
    }

    func testP1_1_V1_1ContainerRoundTrip() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let event = CompletionEvent(sessionStableId: "mig_sess", actualPlayedSeconds: 600, isQualifying: true)
        context.insert(event)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<CompletionEvent>())
        XCTAssertEqual(fetched.count, 1)
    }

    // MARK: - P1-3: outbox enqueue + flush

    func testP1_3_OutboxFlushReplaysQueuedCompletion() async throws {
        let container = try inMemoryContainer()
        let actor = ProgressActor(modelContainer: container)
        let queuedId = UUID()

        try await actor.enqueuePendingCompletion(
            id: queuedId,
            sessionStableId: "outbox_sess",
            courseId: "Basics",
            playedSeconds: 600.0,
            isQualifying: true,
            contentType: "meditation",
            timestamp: Date(),
            timeZoneIdentifier: "UTC",
            gmtOffsetSeconds: 0
        )
        let queuedCount = try await actor.pendingCompletionCount()
        XCTAssertEqual(queuedCount, 1)
        let hasBeforeFlush = try await actor.hasCompletion(id: queuedId)
        XCTAssertFalse(hasBeforeFlush)

        let remaining = try await actor.flushPendingCompletions()
        XCTAssertEqual(remaining, 0)
        let drainedCount = try await actor.pendingCompletionCount()
        XCTAssertEqual(drainedCount, 0)
        let hasAfterFlush = try await actor.hasCompletion(id: queuedId)
        XCTAssertTrue(hasAfterFlush)

        let events = try await actor.fetchAllCompletionEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.sessionStableId, "outbox_sess")
    }

    func testP1_3_OutboxFlushSkipsDuplicatesWithoutLoss() async throws {
        let container = try inMemoryContainer()
        let actor = ProgressActor(modelContainer: container)
        let dupeId = UUID()

        _ = try await actor.recordCompletion(
            id: dupeId,
            sessionStableId: "dupe_sess",
            playedSeconds: 600.0,
            isQualifying: true
        )
        try await actor.enqueuePendingCompletion(
            id: dupeId,
            sessionStableId: "dupe_sess",
            courseId: nil,
            playedSeconds: 600.0,
            isQualifying: true,
            contentType: "meditation",
            timestamp: Date(),
            timeZoneIdentifier: "UTC",
            gmtOffsetSeconds: 0
        )

        let remaining = try await actor.flushPendingCompletions()
        XCTAssertEqual(remaining, 0)
        let events = try await actor.fetchAllCompletionEvents()
        XCTAssertEqual(events.count, 1, "Flush must not duplicate an already-persisted event.")
    }

    // MARK: - P1-2: reflection attaches only by exact id

    func testP1_2_ReflectionByExactIdOnly() async throws {
        let container = try inMemoryContainer()
        let actor = ProgressActor(modelContainer: container)

        let firstId = try await actor.recordCompletion(
            sessionStableId: "sess_a", playedSeconds: 600.0, isQualifying: true
        )
        let secondId = try await actor.recordCompletion(
            sessionStableId: "sess_b", playedSeconds: 600.0, isQualifying: true
        )

        try await actor.saveReflection(for: secondId, note: "heavier")
        let events = try await actor.fetchAllCompletionEvents()
        let first = events.first(where: { $0.id == firstId })
        let second = events.first(where: { $0.id == secondId })
        XCTAssertNil(first?.reflectionNote, "Reflection must never leak onto another session's event.")
        XCTAssertEqual(second?.reflectionNote, "heavier")
    }

    // MARK: - P1-4: scoped import reads through a temp copy

    @MainActor
    func testP1_4_ScopedImportParsesBackupCopy() throws {
        let stats = BackupStats(totalMindfulMinutes: 10, completedSessionsCount: 1, currentStreak: 1, bestStreak: 1)
        let doc = MindSpaceBackupDocument(
            stats: stats,
            userSettings: BackupUserSettings(defaultDurationMinutes: 10, reminderTime: "08:00", themeMode: "quiet_cosmos", hideStreak: false, compassionPassCount: 0),
            completionEvents: [],
            favorites: [],
            achievements: []
        )
        let sourceURL = try ProgressTransferManager.shared.exportToFile(document: doc)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let parsed = try ProgressTransferManager.shared.parseBackupDocument(gainingAccessTo: sourceURL)
        XCTAssertEqual(parsed.completionEvents.count, 0)
        XCTAssertEqual(parsed.userSettings.reminderTime, "08:00")
    }

    // MARK: - P1-8: completion info distinguishes stop/switch finalization

    @MainActor
    func testP1_8_CompletionInfoDefaultsToNaturalFinish() {
        let track = PlayableTrack(id: "t", title: "T", relativePath: "p", duration: 600.0)
        let natural = PlaybackCompletionInfo(track: track, actualMinutes: 10, isQualifying: true, completionId: UUID())
        XCTAssertFalse(natural.finalizedByStopOrSwitch)
        XCTAssertFalse(natural.isPersisted)

        let stopped = PlaybackCompletionInfo(
            track: track, actualMinutes: 5, isQualifying: false,
            completionId: UUID(), finalizedByStopOrSwitch: true, isPersisted: true
        )
        XCTAssertTrue(stopped.finalizedByStopOrSwitch)
        XCTAssertTrue(stopped.isPersisted)
    }
}
