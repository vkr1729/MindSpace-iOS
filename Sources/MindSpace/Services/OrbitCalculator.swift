import Foundation

public struct OrbitStats: Sendable {
    public let currentStreak: Int
    public let bestStreak: Int
    public let totalMindfulMinutes: Int
    public let completedSessionsCount: Int
    public let nextMilestoneDays: Int
    public let compassionPassesAvailable: Int
    public let compassionPassUsedCount: Int
    public let activeDates: Set<String> // YYYY-MM-DD (all mindful activity)
    public let dailyMinutes: [String: Int] // YYYY-MM-DD -> total minutes
}

public struct CelestialAchievement: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let requiredStreak: Int
    public let iconName: String
    public let isUnlocked: Bool
}

/// Computes inner orbit streaks, compassion pass protection, mindful minutes, and heatmap data.
public struct OrbitCalculator: Sendable {
    public static let sensitiveTopicKeywords = [
        "depression", "grief", "cancer", "panic", "coping with cancer", "anxious moments", "sos"
    ]
    
    public init() {}
    
    /// Determines whether a course or track is a sensitive emotional topic exempt from gamified streak badges.
    public static func isSensitiveTopic(courseName: String?) -> Bool {
        guard let name = courseName?.lowercased() else { return false }
        return sensitiveTopicKeywords.contains { name.contains($0) }
    }
    
    /// Determines whether a completion event is eligible to advance the meditation Orbit streak.
    public static func isStreakEligible(event: CompletionEvent) -> Bool {
        guard event.isQualifyingMeditation else { return false }
        if isSensitiveTopic(courseName: event.courseId) { return false }
        let type = event.contentType.lowercased()
        if type == "sleep" || type == "video" || type == "sos" || type == "sensitive" {
            return false
        }
        return true
    }
    
    public func calculateStats(
        events: [CompletionEvent],
        existingCompassionPasses: Int = 0,
        lastUsedPassDate: Date? = nil
    ) -> OrbitStats {
        return calculateStats(
            events: events,
            calendar: .current,
            today: Date(),
            existingCompassionPasses: existingCompassionPasses,
            lastUsedPassDate: lastUsedPassDate
        )
    }
    
    public func calculateStats(
        events: [CompletionEvent],
        calendar: Calendar = .current,
        today: Date = Date(),
        existingCompassionPasses: Int = 0,
        lastUsedPassDate: Date? = nil
    ) -> OrbitStats {
        let qualifyingEvents = events.filter { $0.isQualifyingMeditation }
        
        // Total mindful minutes and sessions include all listening content
        let totalSeconds = qualifyingEvents.reduce(0.0) { $0 + $1.actualPlayedSeconds }
        let totalMinutes = Int(totalSeconds / 60.0)
        let totalCount = qualifyingEvents.count
        
        // Map all qualifying activity to unique calendar day strings "YYYY-MM-DD"
        var dailyMinutes: [String: Int] = [:]
        for event in qualifyingEvents {
            let dayKey = DateFormatterCache.dayKey(from: event.timestamp, timeZoneIdentifier: event.timeZoneIdentifier)
            let mins = Int(event.actualPlayedSeconds / 60.0)
            dailyMinutes[dayKey, default: 0] += max(1, mins)
        }
        let allActiveDays = Set(dailyMinutes.keys)
        
        // Filter events strictly eligible for Orbit streaks (meditation only, excluding passive/sensitive)
        let streakEvents = qualifyingEvents.filter { Self.isStreakEligible(event: $0) }
        var streakDays: Set<String> = []
        for event in streakEvents {
            let dayKey = DateFormatterCache.dayKey(from: event.timestamp, timeZoneIdentifier: event.timeZoneIdentifier)
            streakDays.insert(dayKey)
        }
        
        // Passes are earned from consecutive practice (1 per 7-day cycle of the
        // historical best), not from lifetime non-consecutive active days.
        let historicalBest = computeHistoricalBestStreak(uniqueDays: streakDays, calendar: calendar)
        let earnedFromHistory = historicalBest / 7
        let initialAvailablePasses = max(existingCompassionPasses, earnedFromHistory)

        var passesAvailable = initialAvailablePasses
        var confirmedPassesUsed = 0
        var tentativePassesUsed = 0
        var tentativeDates: [Date] = []
        var recordedUsedDates: [Date] = []
        if let last = lastUsedPassDate {
            recordedUsedDates.append(last)
        }

        // Anchor traversal at the latest practiced day when the device
        // travelled westward, so future-dated events are not skipped.
        // Bounded to 3 days: real dateline travel shifts ≤1 day; anything
        // farther out is a mis-dated event and must not inflate the streak.
        var startCursor = calendar.startOfDay(for: today)
        let todayKey = DateFormatterCache.dayKey(from: startCursor)
        if !streakDays.contains(todayKey) {
            let latestKey = streakDays.filter { $0 > todayKey }.max()
            if let latest = latestKey,
               let latestDate = DateFormatterCache.dateFromDayKey(latest) {
                let daysAhead = calendar.dateComponents([.day], from: startCursor, to: calendar.startOfDay(for: latestDate)).day ?? 0
                if daysAhead >= 1, daysAhead <= 3 {
                    startCursor = calendar.startOfDay(for: latestDate)
                }
            }
        }

        // Calculate current streak working backwards from today
        let checkDate = startCursor

        var cursor = checkDate
        var consecutiveDays = 0
        var consecutiveMisses = 0

        // Check if today was practiced
        if !streakDays.contains(DateFormatterCache.dayKey(from: checkDate)) {
            // If today is not practiced yet, allow streak calculation to begin from yesterday without breaking
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) {
                cursor = yesterday
            }
        }

        var checkedCount = 0
        var confirmedStreak = 0
        while checkedCount < 3650 {
            let key = DateFormatterCache.dayKey(from: cursor)
            if streakDays.contains(key) {
                consecutiveDays += 1
                confirmedStreak = consecutiveDays
                consecutiveMisses = 0
                // A practiced day confirms any tentatively protected miss.
                if tentativePassesUsed > 0 {
                    confirmedPassesUsed += tentativePassesUsed
                    passesAvailable -= tentativePassesUsed
                    recordedUsedDates.append(contentsOf: tentativeDates)
                    tentativePassesUsed = 0
                    tentativeDates.removeAll()
                }
            } else {
                consecutiveMisses += 1
                if consecutiveMisses > 1 {
                    // Two misses in a row: roll back the unconfirmed pass.
                    tentativePassesUsed = 0
                    tentativeDates.removeAll()
                    break
                }

                // Check if a pass can be used for this single missed day
                let pendingDates = recordedUsedDates + tentativeDates
                let canUseInRollingWindow = pendingDates.allSatisfy { prevUsed in
                    let diffDays = abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: prevUsed), to: cursor).day ?? 0)
                    return diffDays >= 30
                }

                if passesAvailable - tentativePassesUsed > 0 && canUseInRollingWindow {
                    tentativePassesUsed += 1
                    tentativeDates.append(cursor)
                    consecutiveDays += 1 // Tentatively protected by Compassion Pass
                } else {
                    tentativePassesUsed = 0
                    tentativeDates.removeAll()
                    break
                }
            }

            guard let prevDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prevDay
            checkedCount += 1
        }

        let currentStreak = confirmedStreak
        let bestStreak = max(currentStreak, historicalBest)
        
        let milestones = [7, 14, 30, 60, 100, 365]
        let nextMilestone = milestones.first(where: { $0 > currentStreak }) ?? (currentStreak + 30)
        
        return OrbitStats(
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalMindfulMinutes: totalMinutes,
            completedSessionsCount: totalCount,
            nextMilestoneDays: nextMilestone,
            compassionPassesAvailable: passesAvailable,
            compassionPassUsedCount: confirmedPassesUsed,
            activeDates: allActiveDays,
            dailyMinutes: dailyMinutes
        )
    }
    
    private func computeHistoricalBestStreak(
        uniqueDays: Set<String>,
        calendar: Calendar
    ) -> Int {
        guard !uniqueDays.isEmpty else { return 0 }
        let sortedDays = uniqueDays.sorted()
        var maxStreak = 0
        var currentRunning = 0
        var previousDate: Date?
        
        for dayStr in sortedDays {
            guard let date = DateFormatterCache.dateFromDayKey(dayStr) else { continue }
            if let prev = previousDate {
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: prev),
                   calendar.isDate(nextDay, inSameDayAs: date) {
                    currentRunning += 1
                } else {
                    currentRunning = 1
                }
            } else {
                currentRunning = 1
            }
            previousDate = date
            maxStreak = max(maxStreak, currentRunning)
        }
        return maxStreak
    }
    
    public func getAchievements(currentStreak: Int, totalSessions: Int) -> [CelestialAchievement] {
        [
            CelestialAchievement(
                id: "first_orbit",
                title: "First Orbit",
                description: "Complete a 7-day unbroken meditation orbit",
                requiredStreak: 7,
                iconName: "sparkles",
                isUnlocked: currentStreak >= 7
            ),
            CelestialAchievement(
                id: "stellar_start",
                title: "Stellar Start",
                description: "Maintain a 14-day meditation orbit",
                requiredStreak: 14,
                iconName: "star.circle.fill",
                isUnlocked: currentStreak >= 14
            ),
            CelestialAchievement(
                id: "deep_space",
                title: "Deep Space",
                description: "Reach a 30-day celestial meditation orbit",
                requiredStreak: 30,
                iconName: "globe.americas.fill",
                isUnlocked: currentStreak >= 30
            ),
            CelestialAchievement(
                id: "century_constellation",
                title: "Century Constellation",
                description: "100 mindful meditation sessions",
                requiredStreak: 100,
                iconName: "sun.max.fill",
                isUnlocked: totalSessions >= 100
            )
        ]
    }
}
