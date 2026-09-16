import Foundation

public struct RecommendedItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let durationLabel: String
    public let reason: String
    public let track: PlayableTrack
    
    public init(
        id: String,
        title: String,
        subtitle: String,
        durationLabel: String,
        reason: String,
        track: PlayableTrack
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.durationLabel = durationLabel
        self.reason = reason
        self.track = track
    }
}

/// Deterministic on-device recommendation engine based on user goals, history, time of day, and duration.
public struct RecommendationEngine: Sendable {
    public static let shared = RecommendationEngine()
    
    public init() {}
    
    public func getRecommendations(
        manifest: CatalogManifest?,
        settings: UserSettings,
        completedSessionIDs: Set<String>,
        currentTime: Date = Date()
    ) -> [RecommendedItem] {
        guard let manifest = manifest else { return [] }
        
        var recommendations: [RecommendedItem] = []
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let preferredMinutes = settings.defaultDurationMinutes
        let goals = Set(settings.selectedGoals.map { $0.lowercased() })
        
        // 1. Course Next Session Recommendation
        for category in manifest.categories {
            let matchesGoal = goals.isEmpty || Self.categoryMatchesGoals(category.name, goals: goals)
            for course in category.courses {
                let uncompleted = course.sessions.filter { !completedSessionIDs.contains($0.id) }
                if let next = uncompleted.first {
                    let mins = max(1, Int(round(next.duration / 60.0)))
                    let track = PlayableTrack(
                        id: next.id,
                        title: next.title,
                        courseName: course.name,
                        relativePath: next.relativePath,
                        duration: next.duration,
                        videoAttachmentPath: next.videoAttachments?.first?.relativePath,
                        dayNumber: next.dayNumber,
                        contentType: "meditation"
                    )
                    recommendations.append(RecommendedItem(
                        id: "rec_course_\(course.id)",
                        title: "\(course.name) — Day \(next.dayNumber)",
                        subtitle: category.name,
                        durationLabel: "\(mins) min",
                        reason: matchesGoal ? "Matches your practice goals" : "Continue your journey",
                        track: track
                    ))
                    break
                }
            }
            if recommendations.count >= 2 { break }
        }
        
        // 2. Time-of-day and goal-aligned Single Sessions
        var timeReason = "Midday mindful pause"
        let timeTargets: [String]
        if hour < 12 {
            timeTargets = ["good morning", "everyday"]
            timeReason = "Morning clarity & focus"
        } else if hour < 17 {
            timeTargets = ["unwind", "rough day", "at work"]
            timeReason = "Afternoon mental reset"
        } else {
            timeTargets = ["good night", "sleep sounds", "unwind"]
            timeReason = "Evening wind-down & rest"
        }

        for singleCat in manifest.singlesCategories {
            let catNameLower = singleCat.name.lowercased()
            let isTimeMatch = timeTargets.contains(where: { catNameLower.contains($0) })
            let isGoalMatch = goals.contains(where: { catNameLower.contains($0) })
                || Self.categoryMatchesGoals(singleCat.name, goals: goals)

            if isTimeMatch || isGoalMatch {
                // Prefer unplayed sessions, closest to preferred duration
                let candidateSessions = singleCat.sessions
                    .filter { !completedSessionIDs.contains($0.id) }
                    .sorted { a, b in
                        let diffA = abs(Int(round(a.duration / 60.0)) - preferredMinutes)
                        let diffB = abs(Int(round(b.duration / 60.0)) - preferredMinutes)
                        return diffA < diffB
                    }

                if let candidate = candidateSessions.first {
                    let mins = max(1, Int(round(candidate.duration / 60.0)))
                    let track = PlayableTrack(
                        id: candidate.id,
                        title: candidate.title,
                        courseName: singleCat.name,
                        relativePath: candidate.relativePath,
                        duration: candidate.duration,
                        contentType: singleCat.name.lowercased().contains("sleep") ? "sleep" : "meditation"
                    )
                    recommendations.append(RecommendedItem(
                        id: "rec_single_\(candidate.id)",
                        title: candidate.title,
                        subtitle: singleCat.name,
                        durationLabel: "\(mins) min",
                        reason: isGoalMatch ? "Aligned with your focus" : timeReason,
                        track: track
                    ))
                }
            }
            if recommendations.count >= 4 { break }
        }
        
        return recommendations
    }

    /// Maps onboarding goal vocabulary (Stress, Focus, Sleep...) to the actual
    /// catalog category names, which use a different taxonomy.
    private static func categoryMatchesGoals(_ categoryName: String, goals: Set<String>) -> Bool {
        let lower = categoryName.lowercased()
        for goal in goals {
            switch goal {
            case "learn": if lower.contains("foundation") || lower.contains("classic") { return true }
            case "stress": if lower.contains("anxious") || lower.contains("rough day") || lower.contains("sos") || lower.contains("unwind") { return true }
            case "sleep": if lower.contains("sleep") || lower.contains("good night") { return true }
            case "focus": if lower.contains("work") || lower.contains("focus") || lower.contains("walking") { return true }
            case "happiness": if lower.contains("happiness") || lower.contains("good morning") { return true }
            case "difficult moments": if lower.contains("sos") || lower.contains("rough day") || lower.contains("anxious") { return true }
            case "work": if lower.contains("work") { return true }
            case "sport": if lower.contains("sport") || lower.contains("working out") { return true }
            default: if lower.contains(goal) { return true }
            }
        }
        return false
    }
}
