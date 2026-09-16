import SwiftUI
import SwiftData

/// Screen 6: Progress & Journey Dashboard (Canonical Blueprint)
/// Reference: Mock Screen Codex.png
public struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var catalogService = CatalogService.shared
    
    @Query(sort: \CompletionEvent.timestamp, order: .reverse) private var completionEvents: [CompletionEvent]
    @Query(sort: \PlaybackResume.updatedAt, order: .reverse) private var resumes: [PlaybackResume]
    @Query private var settingsList: [UserSettings]
    
    @Binding private var path: NavigationPath

    public init(path: Binding<NavigationPath>? = nil) {
        if let path {
            _path = path
        } else {
            _path = .constant(NavigationPath())
        }
    }
    
    private var orbitStats: OrbitStats {
        let passes = settingsList.first?.compassionPassCount ?? 0
        return OrbitCalculator().calculateStats(
            events: completionEvents,
            existingCompassionPasses: passes
        )
    }
    
    private var achievements: [CelestialAchievement] {
        OrbitCalculator().getAchievements(
            currentStreak: orbitStats.currentStreak,
            totalSessions: orbitStats.completedSessionsCount
        )
    }
    
    private var inProgressCourses: [(course: CatalogCourse, doneCount: Int)] {
        guard let allCourses = catalogService.manifest?.categories.flatMap({ $0.courses }) else { return [] }
        let completedIDs = Set(completionEvents.filter { $0.isQualifyingMeditation }.map { $0.sessionStableId })
        let resumedCourseNames = Set(resumes.compactMap { $0.courseName })
        
        return allCourses.compactMap { course in
            let done = course.sessions.filter { completedIDs.contains($0.id) }.count
            let isResumed = resumedCourseNames.contains(course.name)
            if done > 0 || isResumed {
                return (course, done)
            }
            return nil
        }
    }
    
    public var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                CosmosTheme.spaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // MARK: - Header
                        HStack {
                            Text("Your journey")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
                            Spacer()
                            
                            NavigationLink(destination: SettingsView()) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 20))
                                    .foregroundColor(CosmosTheme.moonLavender)
                                    .frame(width: 40, height: 40)
                                    .background(CosmosTheme.spaceCard)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // MARK: - Top Metric Badges (3 Horizontally)
                        HStack(spacing: 12) {
                            if settingsList.first?.hideStreak != true {
                                metricBadge(
                                    title: "\(orbitStats.currentStreak) day Orbit",
                                    subtitle: "\(orbitStats.currentStreak)/\(orbitStats.nextMilestoneDays) days",
                                    icon: "sparkle",
                                    iconColor: CosmosTheme.starlightGold
                                )
                            }
                            
                            metricBadge(
                                title: "\(orbitStats.totalMindfulMinutes) min",
                                subtitle: "mindful time",
                                icon: "clock.fill",
                                iconColor: CosmosTheme.cosmicPurple
                            )
                            
                            metricBadge(
                                title: "\(orbitStats.completedSessionsCount)",
                                subtitle: "sessions",
                                icon: "star.fill",
                                iconColor: CosmosTheme.solarCoral
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Monthly Activity Heatmap
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Activity Heatmap")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                                .padding(.horizontal, 20)
                            
                            MonthlyHeatmapView(
                                activeDates: orbitStats.activeDates,
                                dailyMinutes: orbitStats.dailyMinutes
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // MARK: - Course Progress Section (Only Courses Started / In Progress)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Course Progress")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                
                                Spacer()
                                
                                if !inProgressCourses.isEmpty {
                                    Text("\(inProgressCourses.count) active")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.moonLavender)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            if inProgressCourses.isEmpty {
                                CosmicCard(padding: 20) {
                                    VStack(spacing: 10) {
                                        CelestialPlanetView(style: .purpleRinged, size: 48, hasRings: true)
                                        
                                        Text("No courses in progress yet")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(CosmosTheme.textPrimary)
                                        
                                        Text("Explore the Library to begin your mindful journey. Your active courses will appear here.")
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundColor(CosmosTheme.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                                .padding(.horizontal, 20)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(inProgressCourses, id: \.course.id) { item in
                                        courseProgressRow(course: item.course, doneCount: item.doneCount)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // MARK: - Achievements Gallery
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Celestial Achievements")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                
                                Spacer()
                                
                                Text("\(achievements.filter { $0.isUnlocked }.count)/\(achievements.count) unlocked")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(CosmosTheme.moonLavender)
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(achievements) { achievement in
                                        achievementCard(achievement: achievement)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Subcomponents
    
    @ViewBuilder
    private func metricBadge(title: String, subtitle: String, icon: String, iconColor: Color) -> some View {
        CosmicCard(padding: 12) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private func courseProgressRow(course: CatalogCourse, doneCount: Int) -> some View {
        NavigationLink(destination: CourseDetailView(course: course)) {
            HStack(spacing: 14) {
                CelestialPlanetView(
                    style: planetStyle(for: course.name),
                    size: 38,
                    hasRings: false
                )
                .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                    
                    Text("\(doneCount) of \(course.totalSessions) sessions")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CosmosTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(CosmosTheme.spaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func achievementCard(achievement: CelestialAchievement) -> some View {
        CosmicCard(padding: 14) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked ? CosmosTheme.starlightGold.opacity(0.2) : CosmosTheme.spaceCardBorder)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(achievement.isUnlocked ? CosmosTheme.starlightGold : CosmosTheme.textDisabled)
                }
                
                Text(achievement.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                Text(achievement.description)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 110)
            }
            .frame(width: 120, height: 130)
        }
    }
    
    private func planetStyle(for courseName: String) -> PlanetStyle {
        let lower = courseName.lowercased()
        if lower.contains("foundation") || lower.contains("basics") { return .purpleRinged }
        if lower.contains("health") || lower.contains("anxiety") || lower.contains("stress") { return .auroraTeal }
        if lower.contains("happiness") || lower.contains("relationships") || lower.contains("kindness") { return .solarCoral }
        if lower.contains("work") || lower.contains("focus") || lower.contains("productivity") { return .electricBlue }
        if lower.contains("sleep") || lower.contains("night") || lower.contains("unwind") { return .crescentMoon }
        if lower.contains("brave") || lower.contains("grief") || lower.contains("anger") { return .brave }
        if lower.contains("student") { return .deepLavender }
        if lower.contains("pro") { return .pro }
        if lower.contains("sport") { return .sport }
        return .purpleRinged
    }
}
