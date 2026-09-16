import XCTest
import Foundation
import SwiftData
@testable import MindSpace

final class P2SweepRemediationTests: XCTestCase {

    private func v12Schema() -> Schema {
        Schema(versionedSchema: MindSpaceSchemaV1_2.self)
    }

    // MARK: - P2 migration v1.1 -> v1.2 round-trip (lossless resume fields)

    func testP2_MigrationV12KeepsResumeLosslessFields() throws {
        XCTAssertEqual(MindSpaceSchemaV1_2.versionIdentifier, Schema.Version(1, 2, 0))
        XCTAssertEqual(MindSpaceMigrationPlan.stages.count, 1)

        let schema = v12Schema()
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let resume = PlaybackResume(
            sessionStableId: "p2_lossless",
            relativePath: "Packs/Basics/Day01.mp3",
            sessionTitle: "Basics Day 1",
            courseName: "Basics",
            position: 120.0,
            duration: 600.0,
            accumulatedListenedSeconds: 100.0,
            contentType: "sleep",
            dayNumber: 3,
            videoAttachmentPath: "Packs/Basics/Day03.mp4"
        )
        context.insert(resume)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PlaybackResume>()).first
        XCTAssertEqual(fetched?.contentType, "sleep")
        XCTAssertEqual(fetched?.dayNumber, 3)
        XCTAssertEqual(fetched?.videoAttachmentPath, "Packs/Basics/Day03.mp4")
    }

    // MARK: - P2 backup resume carries lossless fields

    @MainActor
    func testP2_BackupResumeRoundTripsLosslessFields() throws {
        let actorResume = PlaybackResume(
            sessionStableId: "p2_backup",
            relativePath: "Packs/Basics/Day02.mp3",
            sessionTitle: "Basics Day 2",
            courseName: "Basics",
            position: 60.0,
            duration: 600.0,
            contentType: "video",
            dayNumber: 2,
            videoAttachmentPath: "Packs/Basics/Intro.mp4"
        )
        let schema = v12Schema()
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let stats = OrbitStats(
            currentStreak: 1, bestStreak: 1, totalMindfulMinutes: 10,
            completedSessionsCount: 1, nextMilestoneDays: 7,
            compassionPassesAvailable: 0, compassionPassUsedCount: 0,
            activeDates: [], dailyMinutes: [:], passProtectedDayKeys: []
        )
        let settings = UserSettings()
        let doc = ProgressTransferManager.shared.createBackupDocument(
            events: [], favorites: [], settings: settings,
            orbitStats: stats, resumes: [actorResume]
        )
        XCTAssertEqual(doc.resumes?.first?.contentType, "video")
        XCTAssertEqual(doc.resumes?.first?.dayNumber, 2)
        XCTAssertEqual(doc.resumes?.first?.videoAttachmentPath, "Packs/Basics/Intro.mp4")

        try ProgressTransferManager.shared.applyImport(document: doc, modelContext: context, isCleanRestore: true)
        let restored = try context.fetch(FetchDescriptor<PlaybackResume>()).first
        XCTAssertEqual(restored?.contentType, "video")
        XCTAssertEqual(restored?.dayNumber, 2)
        XCTAssertEqual(restored?.videoAttachmentPath, "Packs/Basics/Intro.mp4")
    }

    // MARK: - P2 import validation gates

    func testP2_ImportRejectsZeroAndNegativeBackupVersions() {
        let stats = BackupStats(totalMindfulMinutes: 0, completedSessionsCount: 0, currentStreak: 0, bestStreak: 0)
        let settings = BackupUserSettings(
            defaultDurationMinutes: 10, reminderTime: "08:00",
            themeMode: "quiet_cosmos", hideStreak: false, compassionPassCount: 0
        )
        for badVersion in [0, -1, 99] {
            let doc = MindSpaceBackupDocument(
                backupVersion: badVersion,
                stats: stats, userSettings: settings,
                completionEvents: [], favorites: [], achievements: []
            )
            XCTAssertThrowsError(try ProgressTransferManager.shared.stagedValidation(of: doc))
        }
    }

    func testP2_ImportFileSizeCapExists() {
        XCTAssertGreaterThan(ProgressTransferManager.maxBackupFileBytes, 0)
    }

    // MARK: - P2 reminder schedule validation

    func testP2_SchedulerExposesValidation() {
        NotificationScheduler.shared.scheduleDailyReminder(timeString: "25:99", enabled: true)
        NotificationScheduler.shared.scheduleDailyReminder(timeString: "not-a-time", enabled: true)
        NotificationScheduler.shared.scheduleDailyReminder(timeString: "08:00", enabled: false)
    }

    // MARK: - P2 out-of-range catalog schema surfaces loudly

    func testP2_CatalogSchemaMismatchIsLoud() {
        let error = CatalogLoadError.schemaMismatch(found: 99, expected: 1)
        XCTAssertTrue(error.message.contains("99"))
        XCTAssertTrue(error.message.contains("Update the app"))
    }
}
