import Foundation

public struct OrbitStats: Sendable {
    public let currentStreak: Int
    public let bestStreak: Int
    public let totalMindfulMinutes: Int
    public let completedSessionsCount: Int
    public let nextMilestoneDays: Int
    public let compassionPassesAvailable: Int
    public let compassionPassUsedCount: Int
    public let activeDates: Set<String> // YYYY-MM-DD
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
    
    public func calculateStats(
        events: [CompletionEvent],
        calendar: Calendar = .current,
        today: Date = Date(),
        existingCompassionPasses: Int = 0
    ) -> OrbitStats {
        let qualifyingEvents = events.filter { $0.isQualifyingMeditation }
        
        // Calculate total mindful minutes
        let totalSeconds = qualifyingEvents.reduce(0.0) { $0 + $1.actualPlayedSeconds }
        let totalMinutes = Int(totalSeconds / 60.0)
        let totalCount = qualifyingEvents.count
        
        // Map events to unique local calendar day strings "YYYY-MM-DD"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        
        var dailyMinutes: [String: Int] = [:]
        var daySessions: [String: [CompletionEvent]] = [:]
        
        for event in qualifyingEvents {
            let dayKey = formatter.string(from: event.timestamp)
            let mins = Int(event.actualPlayedSeconds / 60.0)
            dailyMinutes[dayKey, default: 0] += max(1, mins)
            daySessions[dayKey, default: []].append(event)
        }
        
        let uniqueDays = Set(dailyMinutes.keys)
        
        // Calculate Streaks with Compassion Pass support
        var currentStreak = 0
        var bestStreak = 0
        var passesAvailable = existingCompassionPasses
        var passesUsed = 0
        
        // Start checking backwards from today
        var checkDate = calendar.startOfDay(for: today)
        let todayKey = formatter.string(from: checkDate)
        
        // If today is practiced, start streak = 1; if not, check if yesterday was practiced
        var consecutiveDays = 0
        var usedPassForRecentMiss = false
        
        // Rolling backwards day-by-day
        var cursor = checkDate
        var checkedCount = 0
        
        while checkedCount < 365 {
            let key = formatter.string(from: cursor)
            if uniqueDays.contains(key) {
                consecutiveDays += 1
                // Earning a compassion pass for every 7 days reached
                if consecutiveDays % 7 == 0 {
                    passesAvailable += 1
                }
            } else {
                // If today itself has not been practiced yet, allow streak to continue from yesterday
                if cursor == checkDate {
                    // Today not yet practiced, continue checking yesterday
                } else if passesAvailable > 0 && !usedPassForRecentMiss {
                    // Use Compassion Pass for 1 missed day
                    passesAvailable -= 1
                    passesUsed += 1
                    usedPassForRecentMiss = true
                    consecutiveDays += 1 // Compassion pass keeps orbit intact
                } else {
                    break
                }
            }
            
            guard let prevDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prevDay
            checkedCount += 1
        }
        
        currentStreak = consecutiveDays
        bestStreak = max(currentStreak, computeHistoricalBestStreak(uniqueDays: uniqueDays, calendar: calendar, formatter: formatter))
        
        // Next milestone: 7 -> 14 -> 30 -> 60 -> 100 -> 365
        let milestones = [7, 14, 30, 60, 100, 365]
        let nextMilestone = milestones.first(where: { $0 > currentStreak }) ?? (currentStreak + 30)
        
        return OrbitStats(
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalMindfulMinutes: totalMinutes,
            completedSessionsCount: totalCount,
            nextMilestoneDays: nextMilestone,
            compassionPassesAvailable: passesAvailable,
            compassionPassUsedCount: passesUsed,
            activeDates: uniqueDays,
            dailyMinutes: dailyMinutes
        )
    }
    
    private func computeHistoricalBestStreak(
        uniqueDays: Set<String>,
        calendar: Calendar,
        formatter: DateFormatter
    ) -> Int {
        guard !uniqueDays.isEmpty else { return 0 }
        let sortedDays = uniqueDays.sorted()
        var maxStreak = 0
        var currentRunning = 0
        var previousDate: Date?
        
        for dayStr in sortedDays {
            guard let date = formatter.date(from: dayStr) else { continue }
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
                description: "Complete a 7-day unbroken orbit",
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
                description: "Reach a 30-day celestial orbit",
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
