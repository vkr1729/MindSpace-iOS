import SwiftUI

/// Ambient celestial starfield background with subtle twinkle effects.
/// Uses pre-computed star coordinates and GPU-accelerated drawingGroup layer opacity
/// to eliminate continuous main-thread Canvas CPU execution and save battery.
public struct StarsBackgroundView: View {
    private struct Star: Identifiable, Sendable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }
    
    // Pre-computed deterministic pseudo-random star distribution (0 heap allocations on view init)
    private static let precomputedStars: [Star] = {
        var stars: [Star] = []
        for i in 0..<75 {
            let x = CGFloat(((i * 73 + 19) % 100)) / 100.0
            let y = CGFloat(((i * 97 + 31) % 100)) / 100.0
            let size: CGFloat = (i % 7 == 0) ? 2.5 : ((i % 3 == 0) ? 1.8 : 1.0)
            let opacity = (i % 5 == 0) ? 0.75 : 0.35
            stars.append(Star(id: i, x: x, y: y, size: size, opacity: opacity))
        }
        return stars
    }()
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTwinkling = false
    
    public init() {}
    
    public var body: some View {
        Canvas { context, size in
            for star in Self.precomputedStars {
                let rect = CGRect(
                    x: star.x * size.width,
                    y: star.y * size.height,
                    width: star.size,
                    height: star.size
                )
                context.opacity = star.opacity
                context.fill(Circle().path(in: rect), with: .color(Color.white))
            }
        }
        .drawingGroup()
        .opacity(isTwinkling ? 0.72 : 1.0)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                isTwinkling = true
            }
        }
        .background(CosmosTheme.spaceBackground)
        .ignoresSafeArea()
    }
}

/// Pill filter chip button with tactile feedback and glowing starlight state
public struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    public init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            HapticService.shared.light()
            action()
        }) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? CosmosTheme.textPrimary : CosmosTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ?
                    LinearGradient(
                        colors: [CosmosTheme.cosmicPurple, Color(hex: "#6344E0")],
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
                    Capsule()
                        .stroke(isSelected ? CosmosTheme.cosmicPurple.opacity(0.8) : CosmosTheme.spaceCardBorder, lineWidth: 1)
                )
                .shadow(color: isSelected ? CosmosTheme.cosmicPurple.opacity(0.35) : Color.clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.cosmicPressable)
    }
}
