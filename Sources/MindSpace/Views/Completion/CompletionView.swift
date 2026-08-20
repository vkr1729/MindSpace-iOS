import SwiftUI
import SwiftData

/// Screen 5: Completion Screen (Canonical Blueprint)
/// Reference: Mock Screen Codex.png
public struct CompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    
    public let sessionTitle: String
    public let courseName: String?
    public let durationMinutes: Int
    
    @Query(sort: \CompletionEvent.timestamp, order: .reverse) private var completionEvents: [CompletionEvent]
    @Query private var settingsList: [UserSettings]
    
    @State private var selectedReflection: String?
    
    public init(
        sessionTitle: String = "Basics — Day 4",
        courseName: String? = "Basics",
        durationMinutes: Int = 12
    ) {
        self.sessionTitle = sessionTitle
        self.courseName = courseName
        self.durationMinutes = max(1, durationMinutes)
    }
    
    private var orbitStats: OrbitStats {
        let passes = settingsList.first?.compassionPassCount ?? 0
        return OrbitCalculator().calculateStats(
            events: completionEvents,
            existingCompassionPasses: passes
        )
    }
    
    public var body: some View {
        ZStack {
            CosmosTheme.spaceBackground.ignoresSafeArea()
            StarsBackgroundView()
            
            VStack(spacing: 24) {
                // MARK: - Header
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(CosmosTheme.spaceCard)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // MARK: - Celebration Title
                VStack(spacing: 8) {
                    Text("Orbit continued")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                    
                    Text("\(durationMinutes) mindful minutes")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(CosmosTheme.starlightGold)
                }
                
                // MARK: - Constellation Arc Visual
                VStack(spacing: 16) {
                    ZStack {
                        // Curved arc line
                        Circle()
                            .trim(from: 0.25, to: 0.75)
                            .stroke(
                                LinearGradient(
                                    colors: [CosmosTheme.cosmicPurple, CosmosTheme.starlightGold, CosmosTheme.solarCoral],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 190, height: 190)
                            .rotationEffect(.degrees(180))
                        
                        // Center Star
                        Image(systemName: "sparkle")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(CosmosTheme.starlightGold)
                            .shadow(color: CosmosTheme.starlightGold.opacity(0.8), radius: 16)
                    }
                    .frame(height: 120)
                    
                    Text("You're building something beautiful.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
                .padding(.vertical, 8)
                
                // MARK: - Milestone Progress Card
                CosmicCard(padding: 16) {
                    HStack(spacing: 14) {
                        CelestialPlanetView(style: .goldenSun, size: 44, hasRings: false)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(max(1, orbitStats.currentStreak)) / \(orbitStats.nextMilestoneDays) days")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
                            Text("Next milestone: \(orbitStats.nextMilestoneDays) days")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                
                // MARK: - Reflection Options
                VStack(spacing: 8) {
                    Text("How are you feeling?")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                    
                    HStack(spacing: 12) {
                        reflectionPill(title: "Lighter", tag: "lighter")
                        reflectionPill(title: "Same", tag: "same")
                        reflectionPill(title: "Heavier", tag: "heavier")
                    }
                }
                
                Spacer()
                
                // MARK: - Action Buttons
                VStack(spacing: 12) {
                    CosmicPrimaryButton("Done") {
                        saveReflection()
                        dismiss()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func saveReflection() {
        if let reflection = selectedReflection, let latest = completionEvents.first {
            latest.reflectionNote = reflection
            try? modelContext.save()
        }
    }
    
    @ViewBuilder
    private func reflectionPill(title: String, tag: String) -> some View {
        let isSel = (selectedReflection == tag)
        Button(action: {
            selectedReflection = tag
            saveReflection()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(isSel ? CosmosTheme.spaceBackground : CosmosTheme.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(isSel ? CosmosTheme.starlightGold : CosmosTheme.spaceCard)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSel ? Color.clear : CosmosTheme.spaceCardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
