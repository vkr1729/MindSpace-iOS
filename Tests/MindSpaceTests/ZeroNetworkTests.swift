import XCTest
import Foundation
@testable import MindSpace

/// Guards the honest privacy posture: no third-party telemetry SDKs, no
/// analytics/crash/ad frameworks, and all first-party networking confined
/// to the GitHub sync path (api.github.com / raw.githubusercontent.com).
final class ZeroNetworkTests: XCTestCase {

    private static let telemetrySymbols = [
        "Firebase", "FirebaseAnalytics", "FirebaseCrashlytics",
        "Mixpanel", "Amplitude", "Segment.io", "TelemetryDeck",
        "Sentry", "Crashlytics", "Answers", "Flurry", "AppsFlyer",
        "Branch.io", "Kochava", "mParticle", "UXCam",
        "FullStory", "LogRocket", "PostHog", "Countly",
        "AdSupport", "AdServices", "GoogleMobileAds", "AppTrackingTransparency",
    ]

    private static let firstPartyHosts = [
        "api.github.com",
        "raw.githubusercontent.com",
    ]

    private func projectSourcesURL() throws -> URL {
        let thisFilePath = URL(fileURLWithPath: #file)
        let projectRoot = thisFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesURL = projectRoot.appendingPathComponent("Sources")
        guard FileManager.default.fileExists(atPath: sourcesURL.path) else {
            throw XCTSkip("Could not locate Sources/ from \(projectRoot.path)")
        }
        return sourcesURL
    }

    private func swiftFiles(under sourcesURL: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: sourcesURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return [] }
        var files: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            files.append(fileURL)
        }
        return files
    }

    func testNoThirdPartyTelemetrySDKs() throws {
        let files = try swiftFiles(under: projectSourcesURL())
        XCTAssertFalse(files.isEmpty)
        var violations: [String] = []
        for fileURL in files {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            for symbol in Self.telemetrySymbols where content.contains(symbol) {
                violations.append("\(fileURL.lastPathComponent) references telemetry symbol '\(symbol)'")
            }
        }
        XCTAssertTrue(violations.isEmpty, "Telemetry SDKs detected: \(violations.joined(separator: ", "))")
    }

    func testNetworkingConfinedToSyncService() throws {
        let files = try swiftFiles(under: projectSourcesURL())
        let allowedFiles: Set<String> = [
            "GitHubSyncService.swift",
            "LibraryPathResolver.swift",
            "SettingsView.swift",
        ]
        var violations: [String] = []
        for fileURL in files where !allowedFiles.contains(fileURL.lastPathComponent) {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            if content.contains("URLSession") {
                violations.append("\(fileURL.lastPathComponent) uses URLSession outside the sync path")
            }
            for host in Self.firstPartyHosts where content.contains(host) {
                violations.append("\(fileURL.lastPathComponent) references '\(host)' outside the sync path")
            }
        }
        XCTAssertTrue(violations.isEmpty, "Networking outside sync path: \(violations.joined(separator: ", "))")
    }

    func testSyncOnlyTouchesFirstPartyGitHubHosts() throws {
        let sourcesURL = try projectSourcesURL()
        let syncFiles = ["GitHubSyncService.swift", "LibraryPathResolver.swift"].map {
            sourcesURL
                .appendingPathComponent("MindSpace")
                .appendingPathComponent($0)
        }
        let urlPattern = try NSRegularExpression(pattern: #"https://([A-Za-z0-9.\-]+)"#)
        var violations: [String] = []
        for fileURL in syncFiles {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let range = NSRange(content.startIndex..., in: content)
            for match in urlPattern.matches(in: content, range: range) {
                guard let hostRange = Range(match.range(at: 1), in: content) else { continue }
                let host = String(content[hostRange])
                if !Self.firstPartyHosts.contains(host) {
                    violations.append("\(fileURL.lastPathComponent) contacts '\(host)'")
                }
            }
        }
        XCTAssertTrue(violations.isEmpty, "Non-GitHub hosts in sync path: \(violations.joined(separator: ", "))")
    }
}
