import SwiftUI
import SwiftData

/// Screen 5: Elevated Completion Screen with Celebration Starburst & Tactile Reflections
/// Reference: Mock Screen Codex.png & UI/UX Pro Max Design Intelligence
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
    @State private var starScale: CGFloat = 0.8
    @State private var starOpacity: Double = 0.5
    
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
            
            // Atmospheric Celebration Glow
            RadialGradient(
                colors: [CosmosTheme.starlightGold.opacity(0.18), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            
            VStack(spacing: 22) {
                // MARK: - Header
                HStack {
                    Spacer()
                    Button(action: {
                        HapticService.shared.light()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(CosmosTheme.spaceCard)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.cosmicPressable)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // MARK: - Celebration Title with Starlight Aura
                VStack(spacing: 6) {
                    Text("Orbit Continued")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                    
                    Text("\(durationMinutes) Mindful Minutes Recorded")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(CosmosTheme.starlightGold)
                }
                
                // MARK: - Constellation Arc Celebration Visual
                VStack(spacing: 14) {
                    ZStack {
                        // Pulsing outer halo
                        Circle()
                            .fill(CosmosTheme.starlightGold.opacity(0.15))
                            .frame(width: 140, height: 140)
                            .scaleEffect(starScale)
                            .opacity(starOpacity)
                        
                        // Curved arc line
                        Circle()
                            .trim(from: 0.25, to: 0.75)
                            .stroke(
                                LinearGradient(
                                    colors: [CosmosTheme.cosmicPurple, CosmosTheme.starlightGold, CosmosTheme.solarCoral],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .frame(width: 190, height: 190)
                            .rotationEffect(.degrees(180))
                        
                        // Center Sparkling Star
                        Image(systemName: "sparkle")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(CosmosTheme.starlightGold)
                            .shadow(color: CosmosTheme.starlightGold.opacity(0.85), radius: 18)
                    }
                    .frame(height: 125)
                    
                    Text("You're building something beautiful.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
                .padding(.vertical, 6)
                
                // MARK: - Milestone Progress Card
                CosmicCard(padding: 16) {
                    HStack(spacing: 14) {
                        CelestialPlanetView(style: .goldenSun, size: 48, hasRings: false)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(max(1, orbitStats.currentStreak)) of \(orbitStats.nextMilestoneDays) Days Orbit")
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
                
                // MARK: - Emotional Reflection Selector
                VStack(spacing: 10) {
                    Text("How are you feeling right now?")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                    
                    HStack(spacing: 12) {
                        reflectionPill(title: "✨ Lighter", tag: "lighter")
                        reflectionPill(title: "🌱 Centered", tag: "same")
                        reflectionPill(title: "⚓ Grounded", tag: "heavier")
                    }
                }
                .padding(.top, 4)
                
                Spacer()
                
                // MARK: - Action Buttons
                VStack(spacing: 12) {
                    CosmicPrimaryButton("Done") {
                        HapticService.shared.medium()
                        saveReflection()
                        dismiss()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            HapticService.shared.success()
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                starScale = 1.25
                starOpacity = 0.85
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
            HapticService.shared.medium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedReflection = tag
            }
            saveReflection()
        }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: isSel ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSel ? CosmosTheme.spaceBackground : CosmosTheme.textPrimary)
                
                if isSel {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(CosmosTheme.spaceBackground)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSel ?
                LinearGradient(
                    colors: [CosmosTheme.starlightGold, Color(hex: "#EAB308")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [CosmosTheme.spaceCard, CosmosTheme.spaceCard],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSel ? Color.clear : CosmosTheme.spaceCardBorder, lineWidth: 1)
            )
            .shadow(color: isSel ? CosmosTheme.starlightGold.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.cosmicPressable)
    }
}
