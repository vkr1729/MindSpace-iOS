import Foundation
import SwiftData

/// Persists compassion-pass consumption so used passes cannot regenerate.
/// The calculator reports `passProtectedDayKeys`; this store derives the
/// durable count + last-used date from the persisted settings row.
public enum CompassionPassStore {
    /// Returns the pass-protected day-keys that are newer than the stored
    /// `lastUsedCompassionPassDate` — the consumption the caller must persist.
    public static func newlyProtectedDayKeys(
        stats: OrbitStats,
        lastUsedPassDate: Date?
    ) -> [String] {
        stats.passProtectedDayKeys.filter { key in
            guard let date = DateFormatterCache.dateFromDayKey(key) else { return false }
            guard let last = lastUsedPassDate else { return true }
            return date > last
        }
    }

    @MainActor
    public static func reconcile(
        stats: OrbitStats,
        settings: UserSettings,
        modelContext: ModelContext
    ) {
        let newlyProtected = newlyProtectedDayKeys(
            stats: stats,
            lastUsedPassDate: settings.lastUsedCompassionPassDate
        )
        guard !newlyProtected.isEmpty else { return }
        settings.compassionPassCount = max(0, settings.compassionPassCount - newlyProtected.count)
        let latestKey = newlyProtected.max() ?? ""
        if let latestDate = DateFormatterCache.dateFromDayKey(latestKey),
           latestDate > (settings.lastUsedCompassionPassDate ?? .distantPast) {
            settings.lastUsedCompassionPassDate = latestDate
        }
        try? modelContext.save()
    }
}
