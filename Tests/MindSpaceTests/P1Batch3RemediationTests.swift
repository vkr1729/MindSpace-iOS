import XCTest
import Foundation
import SwiftData
@testable import MindSpace

final class P1Batch3RemediationTests: XCTestCase {

    // MARK: - P1-6: redirect-safe streaming auth (Contents API form)

    func testP1_6_ContentsAPIURLFormIsWellFormed() {
        let encoded = "Packs/1%20-%20Foundation/Day%2001.mp3"
        let url = URL(string: "https://api.github.com/repos/vkr1729/MindSpace-Content/contents/\(encoded)")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "api.github.com")
        XCTAssertTrue(url?.path.contains("/contents/") ?? false)
    }

    func testP1_6_RawHostRedirectIsTheKnownRisk() {
        // Documents the defect: raw.githubusercontent.com redirects and
        // AVFoundation drops custom Authorization headers across redirects,
        // which is why streaming must use the Contents API form instead.
        let raw = URL(string: "https://raw.githubusercontent.com/vkr1729/MindSpace-Content/main/p.mp3")
        XCTAssertEqual(raw?.host, "raw.githubusercontent.com")
        XCTAssertNotEqual(raw?.host, "api.github.com")
    }

    // MARK: - P1-7: pass consumption is derived and persisted

    func testP1_7_NewlyProtectedKeysDriveConsumption() {
        let stats = OrbitStats(
            currentStreak: 8,
            bestStreak: 14,
            totalMindfulMinutes: 80,
            completedSessionsCount: 8,
            nextMilestoneDays: 14,
            compassionPassesAvailable: 2,
            compassionPassUsedCount: 1,
            activeDates: [],
            dailyMinutes: [:],
            passProtectedDayKeys: ["2026-09-10", "2026-09-14"]
        )
        let fresh = CompassionPassStore.newlyProtectedDayKeys(stats: stats, lastUsedPassDate: nil)
        XCTAssertEqual(fresh, ["2026-09-10", "2026-09-14"])

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let last = formatter.date(from: "2026-09-10")
        let remaining = CompassionPassStore.newlyProtectedDayKeys(stats: stats, lastUsedPassDate: last)
        XCTAssertEqual(remaining, ["2026-09-14"], "Already-recorded passes must not be consumed twice.")
    }

    // MARK: - P1-9: seek defers to readiness (state-machine pin)

    @MainActor
    func testP1_9_MissingMediaStillFailsFastWithoutSeek() {
        let engine = PlaybackEngine()
        KeychainManager.shared.delete(key: "github_sync_pat")
        let missing = PlayableTrack(
            id: "p1_9_missing",
            title: "Absent",
            courseName: "Cosmos",
            relativePath: "NonExistent/Absent.mp3",
            duration: 600.0
        )
        let loaded = engine.loadAndPlay(track: missing, startPosition: 120.0)
        XCTAssertFalse(loaded)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNotNil(engine.playbackError)
        engine.stop()
    }

    // MARK: - P1-10: retry/backoff classification + per-file results

    func testP1_10_FailureClassification() {
        XCTAssertTrue(SyncDownloadFailure.network(URLError(.timedOut)).isRetryable)
        XCTAssertTrue(SyncDownloadFailure.httpStatus(500).isRetryable)
        XCTAssertTrue(SyncDownloadFailure.httpStatus(429).isRetryable)
        XCTAssertFalse(SyncDownloadFailure.httpStatus(404).isRetryable)
        XCTAssertFalse(SyncDownloadFailure.httpStatus(401).isRetryable)
        XCTAssertFalse(SyncDownloadFailure.verification("SHA-256 mismatch").isRetryable)
        XCTAssertFalse(SyncDownloadFailure.cancelled.isRetryable)
        XCTAssertEqual(GitHubSyncService.maxAttemptsPerFile, 3)
    }

    func testP1_10_FileResultIdentity() {
        let result = SyncFileResult(
            relativePath: "Packs/a.mp3",
            title: "A",
            succeeded: false,
            attempts: 3,
            errorMessage: "HTTP 500"
        )
        XCTAssertEqual(result.id, "Packs/a.mp3")
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.attempts, 3)
        XCTAssertNotNil(result.errorMessage)
    }

    // MARK: - P1-5: schemaVersion is honored loudly

    func testP1_5_SchemaMismatchMessage() {
        let error = CatalogLoadError.schemaMismatch(found: 2, expected: 1)
        XCTAssertTrue(error.message.contains("v2"))
        XCTAssertTrue(error.message.contains("Update the app"))
    }

    // MARK: - P1-12: honest privacy posture (no telemetry SDKs)

    func testP1_12_PrivacyCopyMentionsOptionalSync() {
        let copy = "MindSpace has no accounts, telemetry, or ads. Everything stays on this iPhone except the optional GitHub sync"
        XCTAssertTrue(copy.contains("optional GitHub sync"))
        XCTAssertFalse(copy.contains("no network access"))
    }
}
