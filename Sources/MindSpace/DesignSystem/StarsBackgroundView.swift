import SwiftUI

/// Ambient celestial starfield background with subtle twinkle effects.
public struct StarsBackgroundView: View {
    private struct Star: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }
    
    @State private var stars: [Star] = []
    @State private var isTwinkling = false
    
    public init() {}
    
    public var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                for star in stars {
                    let rect = CGRect(
                        x: star.x * size.width,
                        y: star.y * size.height,
                        width: star.size,
                        height: star.size
                    )
                    context.opacity = star.opacity * (isTwinkling ? 0.8 : 1.0)
                    context.fill(Circle().path(in: rect), with: .color(Color.white))
                }
            }
            .onAppear {
                if stars.isEmpty {
                    generateStars()
                }
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    isTwinkling.toggle()
                }
            }
        }
        .background(CosmosTheme.spaceBackground)
        .ignoresSafeArea()
    }
    
    private func generateStars() {
        var newStars: [Star] = []
        // Deterministic pseudo-random star distribution
        for i in 0..<75 {
            let x = CGFloat(((i * 73 + 19) % 100)) / 100.0
            let y = CGFloat(((i * 97 + 31) % 100)) / 100.0
            let size: CGFloat = (i % 7 == 0) ? 2.5 : ((i % 3 == 0) ? 1.8 : 1.0)
            let opacity = (i % 5 == 0) ? 0.75 : 0.35
            newStars.append(Star(x: x, y: y, size: size, opacity: opacity))
        }
        self.stars = newStars
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
