#if DEBUG
import Foundation
import SwiftData

enum UITestSupport {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
    }

    static var shouldResetStore: Bool {
        ProcessInfo.processInfo.arguments.contains("-reset-ui-testing")
    }

    static var skipsOnboarding: Bool {
        ProcessInfo.processInfo.environment["MINDSPACE_UI_TEST_SKIP_ONBOARDING"] != "0"
    }

    static var scenario: String {
        ProcessInfo.processInfo.environment["MINDSPACE_UI_TEST_SCENARIO"] ?? "standard"
    }

    static var downloadingCategoryID: String? {
        scenario == "library-states" ? "fixture_focus" : nil
    }

    static let downloadedPath = "UITest/Basics-Day-1.wav"
    static let completedPath = "UITest/Basics-Day-3.wav"
    static let resetPath = "UITest/Five-Minute-Reset.wav"
    static let sleepPath = "UITest/Soft-Rain.wav"

    static func prepareFilesystem() {
        guard isEnabled else { return }
        let root = LibraryPathResolver.shared.libraryDirectoryURL
        try? FileManager.default.createDirectory(at: root.appendingPathComponent("UITest"), withIntermediateDirectories: true)
        for relativePath in [downloadedPath, completedPath, resetPath, sleepPath] {
            let url = root.appendingPathComponent(relativePath)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? Data("MindSpace deterministic UI-test media fixture".utf8).write(to: url, options: .atomic)
            }
        }
    }

    static var catalogManifest: CatalogManifest {
        let basics = CatalogCourse(
            id: "fixture_basics",
            name: "Basics",
            folderName: "Basics",
            description: "Build a steady meditation practice.",
            totalSessions: 3,
            sessions: [
                CatalogSession(id: "fixture_day_1", title: "Basics — Day 1", dayNumber: 1, relativePath: downloadedPath, duration: 600),
                CatalogSession(id: "fixture_day_2", title: "Basics — Day 2", dayNumber: 2, relativePath: "UITest/Missing-Day-2.wav", duration: 600),
                CatalogSession(id: "fixture_day_3", title: "Basics — Day 3", dayNumber: 3, relativePath: completedPath, duration: 600)
            ]
        )

        let categories = [
            CatalogCategory(
                id: "fixture_foundation",
                type: "pack",
                name: "Foundation",
                folderName: "Foundation",
                order: 1,
                description: "Meditation fundamentals",
                colorHex: "#8BCAB7",
                iconName: "figure.mind.and.body",
                courses: [basics]
            )
        ]

        let singles = [
            SinglesCategory(
                id: "fixture_unwind",
                name: "Unwind",
                folderName: "Unwind",
                description: "Short practices for transitions",
                colorHex: "#8BCAB7",
                iconName: "leaf.fill",
                sessions: [
                    SingleSession(id: "fixture_reset", title: "Five Minute Reset", category: "Unwind", relativePath: resetPath, duration: 300)
                ]
            ),
            SinglesCategory(
                id: "fixture_sleep",
                name: "Sleep Sounds",
                folderName: "Sleep Sounds",
                order: 2,
                description: "Quiet audio for rest",
                colorHex: "#AAB8AE",
                iconName: "waveform",
                sessions: [
                    SingleSession(id: "fixture_rain", title: "Soft Rain - 10 min", category: "Sleep Sounds", relativePath: sleepPath, duration: 600)
                ]
            ),
            SinglesCategory(
                id: "fixture_sos",
                name: "SOS",
                folderName: "SOS",
                order: 3,
                description: "Immediate grounding",
                colorHex: "#EF9D9D",
                iconName: "lifepreserver.fill",
                sessions: [
                    SingleSession(id: "fixture_sos_session", title: "Steady Breathing", category: "SOS", relativePath: "UITest/Missing-SOS.wav", duration: 180)
                ]
            ),
            SinglesCategory(
                id: "fixture_focus",
                name: "Focus",
                folderName: "Focus",
                order: 4,
                description: "Clear attention",
                colorHex: "#8CB9C4",
                iconName: "scope",
                sessions: [
                    SingleSession(id: "fixture_focus_session", title: "Clear Attention", category: "Focus", relativePath: "UITest/Missing-Focus.wav", duration: 480)
                ]
            )
        ]

        return CatalogManifest(
            schemaVersion: 1,
            generatedAt: "2026-08-30T00:00:00Z",
            totalFiles: 8,
            totalDuration: 3_480,
            totalDurationHours: 0.97,
            totalSizeBytes: 0,
            categories: categories,
            singlesCategories: singles
        )
    }

    @MainActor private static var didPrepareStore = false

    @MainActor
    static func prepareStore(_ context: ModelContext) {
        guard isEnabled, !didPrepareStore else { return }
        didPrepareStore = true

        if shouldResetStore {
            (try? context.fetch(FetchDescriptor<CompletionEvent>()))?.forEach(context.delete)
            (try? context.fetch(FetchDescriptor<PlaybackResume>()))?.forEach(context.delete)
            (try? context.fetch(FetchDescriptor<FavoriteItem>()))?.forEach(context.delete)
            (try? context.fetch(FetchDescriptor<UserSettings>()))?.forEach(context.delete)
        }

        var settingsDescriptor = FetchDescriptor<UserSettings>()
        settingsDescriptor.fetchLimit = 1
        if (try? context.fetch(settingsDescriptor))?.first == nil {
            context.insert(UserSettings(
                hasCompletedOnboarding: skipsOnboarding,
                selectedGoals: ["Stress", "Focus", "Sleep"],
                hasAcknowledgedDisclaimer: skipsOnboarding
            ))
        }

        if scenario == "progress", (try? context.fetch(FetchDescriptor<CompletionEvent>()))?.isEmpty != false {
            let calendar = Calendar.current
            for offset in 0..<3 {
                let timestamp = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
                context.insert(CompletionEvent(
                    sessionStableId: "fixture_progress_\(offset)",
                    courseId: "Basics",
                    actualPlayedSeconds: 600,
                    isQualifying: true,
                    timestamp: timestamp
                ))
            }
        }

        try? context.save()
    }
}
#endif
