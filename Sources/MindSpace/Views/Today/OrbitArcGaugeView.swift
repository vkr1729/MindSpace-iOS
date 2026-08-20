import SwiftUI

/// Dynamic circular gradient arc gauge displaying the user's current Orbit streak and next milestone.
/// Reference: Mock Screen Codex.png (Screen 1 & Screen 6)
public struct OrbitArcGaugeView: View {
    public let currentStreak: Int
    public let milestoneGoal: Int
    public let size: CGFloat
    public let lineWidth: CGFloat
    
    @State private var animatedProgress: Double = 0.0
    
    public init(
        currentStreak: Int = 7,
        milestoneGoal: Int = 14,
        size: CGFloat = 170,
        lineWidth: CGFloat = 14
    ) {
        self.currentStreak = currentStreak
        self.milestoneGoal = max(1, milestoneGoal)
        self.size = size
        self.lineWidth = lineWidth
    }
    
    public init(
        currentStreak: Int = 7,
        milestoneDays: Int = 14,
        totalMinutes: Int = 0,
        passesAvailable: Int = 0,
        size: CGFloat = 170,
        lineWidth: CGFloat = 14
    ) {
        self.currentStreak = currentStreak
        self.milestoneGoal = max(1, milestoneDays)
        self.size = size
        self.lineWidth = lineWidth
    }
    
    private var progress: Double {
        min(1.0, Double(currentStreak) / Double(milestoneGoal))
    }
    
    public var body: some View {
        ZStack {
            // Background Track Arc (270 degrees open at bottom)
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(CosmosTheme.spaceCardBorder.opacity(0.8), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(90))
            
            // Active Gradient Arc
            Circle()
                .trim(from: 0.15, to: 0.15 + (0.70 * animatedProgress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            CosmosTheme.cosmicPurple,
                            CosmosTheme.solarCoral,
                            CosmosTheme.starlightGold
                        ]),
                        center: .center,
                        startAngle: .degrees(135),
                        endAngle: .degrees(405)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(90))
                .shadow(color: CosmosTheme.solarCoral.opacity(0.4), radius: 8, x: 0, y: 0)
            
            // Center Readout Content
            VStack(spacing: 4) {
                Text("\(currentStreak) day")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                Text("Orbit")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(CosmosTheme.starlightGold)
                    .textCase(.uppercase)
                    .tracking(1.2)
                
                Text("\(currentStreak) / \(milestoneGoal) days")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .padding(.top, 2)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: currentStreak) { _, _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animatedProgress = progress
            }
        }
    }
}
