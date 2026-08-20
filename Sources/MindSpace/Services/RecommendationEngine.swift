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
            let matchesGoal = goals.isEmpty || goals.contains(category.name.lowercased())
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
        var targetSingleCategory: String = "Everyday"
        var timeReason = "Midday mindful pause"
        if hour < 12 {
            targetSingleCategory = "Everyday"
            timeReason = "Morning clarity & focus"
        } else if hour < 17 {
            targetSingleCategory = "Feeling Overwhelmed"
            timeReason = "Afternoon mental reset"
        } else {
            targetSingleCategory = "Sleep"
            timeReason = "Evening wind-down & rest"
        }
        
        for singleCat in manifest.singlesCategories {
            let catNameLower = singleCat.name.lowercased()
            let isTimeMatch = catNameLower.contains(targetSingleCategory.lowercased()) || (hour >= 17 && (catNameLower.contains("sleep") || catNameLower.contains("unwind") || catNameLower.contains("good night")))
            let isGoalMatch = goals.contains(where: { catNameLower.contains($0) })
            
            if isTimeMatch || isGoalMatch {
                // Find unplayed or closest to preferred duration
                let candidateSessions = singleCat.sessions.sorted { a, b in
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
}
