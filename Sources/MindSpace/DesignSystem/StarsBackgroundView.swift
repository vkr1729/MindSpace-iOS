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

// MARK: - Reusable Cosmic UI Components

/// Cosmic elevated card container with subtle border and optional glow
public struct CosmicCard<Content: View>: View {
    let padding: CGFloat
    let cornerRadius: CGFloat
    let content: Content
    
    public init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(padding)
            .background(CosmosTheme.spaceCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
            )
    }
}

/// Primary action button with cosmic purple background, glowing aura, and tactile feedback
public struct CosmicPrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #endif
            action()
        }) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundColor(CosmosTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(CosmosTheme.cosmicPurple)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: CosmosTheme.cosmicPurple.opacity(0.4), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

/// Pill filter chip button
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
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? CosmosTheme.textPrimary : CosmosTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? CosmosTheme.cosmicPurple : CosmosTheme.spaceCard)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : CosmosTheme.spaceCardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
