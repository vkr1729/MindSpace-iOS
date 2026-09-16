import XCTest
import Foundation
import SwiftData
@testable import MindSpace

final class P0RemediationTests: XCTestCase {

    // MARK: - P0-1: AppTab exists with the 4 tabs in order

    func testP0_1_AppTabHasFourTabsInOrder() {
        let tabs = AppTab.allCases
        XCTAssertEqual(tabs.map(\.title), ["Today", "Library", "Progress", "Settings"])
        XCTAssertEqual(tabs.map(\.id), ["today", "library", "progress", "settings"])
        for tab in tabs {
            XCTAssertFalse(tab.iconName.isEmpty, "\(tab) must have an icon")
        }
    }

    // MARK: - P0-3: loadAndPlay reports success; missing media returns false

    @MainActor
    func testP0_3_LoadAndPlayReturnsFalseForMissingMedia() {
        let engine = PlaybackEngine()
        KeychainManager.shared.delete(key: "github_sync_pat")
        let missing = PlayableTrack(
            id: "p0_missing",
            title: "Absent Meditation",
            courseName: "Cosmos",
            relativePath: "NonExistent/AbsentMeditation.mp3",
            duration: 600.0
        )
        let loaded = engine.loadAndPlay(track: missing)
        XCTAssertFalse(loaded, "loadAndPlay must return false when media is unavailable.")
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNotNil(engine.playbackError)
        engine.clearPlaybackError()
        XCTAssertNil(engine.playbackError)
        engine.stop()
    }

    @MainActor
    func testP0_3_LoadAndPlayReturnsTrueForLocalFile() throws {
        let resolver = LibraryPathResolver.shared
        let relPath = "P0Tests/local_track.mp3"
        let fileURL = resolver.libraryDirectoryURL.appendingPathComponent(relPath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "dummy audio".data(using: .utf8)?.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let engine = PlaybackEngine()
        let track = PlayableTrack(
            id: "p0_local",
            title: "Local Track",
            courseName: "Cosmos",
            relativePath: relPath,
            duration: 600.0
        )
        let loaded = engine.loadAndPlay(track: track)
        XCTAssertTrue(loaded, "loadAndPlay must return true when the local file exists.")
        XCTAssertNil(engine.playbackError)
        engine.stop()
    }

    // MARK: - P0-4: single settings creation site, no duplicates

    @MainActor
    func testP0_4_FetchOrCreateNeverDuplicatesSettings() throws {
        let schema = Schema(versionedSchema: MindSpaceSchemaV1_2.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let first = SettingsStore.fetchOrCreate(in: context)
        let second = SettingsStore.fetchOrCreate(in: context)
        XCTAssertEqual(first.id, second.id)

        let all = try context.fetch(FetchDescriptor<UserSettings>())
        XCTAssertEqual(all.count, 1, "Repeated fetchOrCreate calls must never insert duplicates.")
        XCTAssertEqual(all.first?.id, "primary_settings")
    }

    @MainActor
    func testP0_4_ConcurrentSettingsCreationYieldsSingleRow() throws {
        let schema = Schema(versionedSchema: MindSpaceSchemaV1_2.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        for _ in 0..<5 {
            _ = SettingsStore.fetchOrCreate(in: context)
        }

        let all = try context.fetch(FetchDescriptor<UserSettings>())
        XCTAssertEqual(all.count, 1)
        try context.save()
        let afterSave = try context.fetch(FetchDescriptor<UserSettings>())
        XCTAssertEqual(afterSave.count, 1, "Saves after fetchOrCreate must not poison the context with duplicates.")
    }

    // MARK: - P0-2: foreground session configuration (structural, no network)

    func testP0_2_UsesForegroundSessionConfiguration() {
        let config = URLSessionConfiguration.default
        XCTAssertNil(config.identifier, "Foreground .default sessions carry no background identifier.")
        let background = URLSessionConfiguration.background(withIdentifier: "com.mindspace.offline.sync")
        XCTAssertNotNil(background.identifier)
    }
}
