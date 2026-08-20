import SwiftUI

/// Canonical "Quiet Cosmos" design tokens and theme constants.
/// Reference: Mock Screen Codex.png & MINDSPACE_DESIGN_SYSTEM_MOCKUPS.md
public enum CosmosTheme {
    // MARK: - Core Backgrounds
    /// Deep midnight navy base (#0B0E17)
    public static let spaceBackground = Color(hex: "#0B0E17")
    /// Elevated nebula card surface (#151B28)
    public static let spaceCard = Color(hex: "#151B28")
    /// Subtle outline card border (#222D42)
    public static let spaceCardBorder = Color(hex: "#222D42")
    /// Elevated pill background (#1C2436)
    public static let spacePill = Color(hex: "#1C2436")
    /// High-contrast glass overlay (#28334E)
    public static let spaceGlass = Color(hex: "#1D253A")
    
    // MARK: - Core Accents
    /// Primary cosmic purple (#7C5CFC) - Primary buttons, active nodes, scrubber
    public static let cosmicPurple = Color(hex: "#7C5CFC")
    /// Starlight gold (#F6D06F) - Completed nodes, streak tips, celestial badges
    public static let starlightGold = Color(hex: "#F6D06F")
    /// Solar coral (#FF7B72) - Orbit gauge gradient end & warm highlights
    public static let solarCoral = Color(hex: "#FF7B72")
    /// Aurora teal (#4ECCA3) - Health & mindfulness accents
    public static let auroraTeal = Color(hex: "#4ECCA3")
    /// Celestial electric blue (#3B82F6) - Work, focus & classic timers
    public static let celestialBlue = Color(hex: "#3B82F6")
    /// Moon lavender (#9D8DF1) - Secondary highlights & calm states
    public static let moonLavender = Color(hex: "#9D8DF1")
    /// Deep cosmic indigo (#4F46E5) - Hero gradient start
    public static let cosmicIndigo = Color(hex: "#4F46E5")
    
    // MARK: - Text Hierarchy
    /// Primary crisp white (#F0F6FC)
    public static let textPrimary = Color(hex: "#F0F6FC")
    /// Muted subtext (#8B949E)
    public static let textSecondary = Color(hex: "#8B949E")
    /// Muted disabled & locked text (#484F58)
    public static let textDisabled = Color(hex: "#484F58")
    
    // MARK: - Ultra-Dark Sleep Mode Palette
    /// 99% OLED pure black (#05070B)
    public static let sleepAbyss = Color(hex: "#05070B")
    /// Minimal contrast card (#0C1018)
    public static let sleepCard = Color(hex: "#0C1018")
    /// Muted warm amber starlight (#B89B4A)
    public static let sleepWarmGold = Color(hex: "#B89B4A")
    
    // MARK: - Gradients
    public static let orbitGaugeGradient = LinearGradient(
        colors: [cosmicPurple, solarCoral, starlightGold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let heroAuraGradient = LinearGradient(
        colors: [cosmicIndigo.opacity(0.4), cosmicPurple.opacity(0.15), Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let purpleGlowGradient = LinearGradient(
        colors: [cosmicPurple, cosmicPurple.opacity(0.6)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let celestialCardGradient = LinearGradient(
        colors: [spaceCard, spaceCard.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let sleepSanctuaryGradient = LinearGradient(
        colors: [Color(hex: "#0F1424"), Color(hex: "#070A12")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Category Ambient Colors
    public static func ambientColor(for categoryName: String) -> Color {
        let lower = categoryName.lowercased()
        if lower.contains("sleep") || lower.contains("night") || lower.contains("unwind") {
            return moonLavender
        } else if lower.contains("health") || lower.contains("anxiety") || lower.contains("stress") || lower.contains("healing") {
            return auroraTeal
        } else if lower.contains("work") || lower.contains("focus") || lower.contains("performance") || lower.contains("student") {
            return celestialBlue
        } else if lower.contains("sos") || lower.contains("reset") || lower.contains("panic") {
            return solarCoral
        } else if lower.contains("brave") || lower.contains("compassion") || lower.contains("self-esteem") {
            return starlightGold
        } else {
            return cosmicPurple
        }
    }
}

// MARK: - Color Hex Initializer
public extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 124, 92, 252) // Default to cosmicPurple
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

// MARK: - Tactile Pressable Button Style
public struct CosmicPressableButtonStyle: ButtonStyle {
    public let hapticType: HapticFeedbackType
    
    public enum HapticFeedbackType {
        case light
        case medium
        case soft
        case none
    }
    
    public init(hapticType: HapticFeedbackType = .light) {
        self.hapticType = hapticType
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    switch hapticType {
                    case .light: HapticService.shared.light()
                    case .medium: HapticService.shared.medium()
                    case .soft: HapticService.shared.soft()
                    case .none: break
                    }
                }
            }
    }
}

public extension ButtonStyle where Self == CosmicPressableButtonStyle {
    static var cosmicPressable: CosmicPressableButtonStyle {
        CosmicPressableButtonStyle(hapticType: .light)
    }
    static var cosmicPrimaryPressable: CosmicPressableButtonStyle {
        CosmicPressableButtonStyle(hapticType: .medium)
    }
}

// MARK: - Cosmic Surface Modifiers
public struct CosmicCardModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let borderColor: Color
    public let padding: CGFloat
    
    public init(cornerRadius: CGFloat = 18, borderColor: Color = CosmosTheme.spaceCardBorder, padding: CGFloat = 16) {
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.padding = padding
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(CosmosTheme.spaceCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

public struct CosmicHeroSurfaceModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let glowColor: Color
    public let padding: CGFloat
    
    public init(cornerRadius: CGFloat = 24, glowColor: Color = CosmosTheme.cosmicPurple, padding: CGFloat = 20) {
        self.cornerRadius = cornerRadius
        self.glowColor = glowColor
        self.padding = padding
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    CosmosTheme.spaceCard
                    glowColor.opacity(0.12)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [glowColor.opacity(0.6), CosmosTheme.spaceCardBorder],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: glowColor.opacity(0.2), radius: 16, x: 0, y: 6)
    }
}

public extension View {
    func cosmicCardStyle(cornerRadius: CGFloat = 18, borderColor: Color = CosmosTheme.spaceCardBorder, padding: CGFloat = 16) -> some View {
        self.modifier(CosmicCardModifier(cornerRadius: cornerRadius, borderColor: borderColor, padding: padding))
    }
    
    func cosmicHeroStyle(cornerRadius: CGFloat = 24, glowColor: Color = CosmosTheme.cosmicPurple, padding: CGFloat = 20) -> some View {
        self.modifier(CosmicHeroSurfaceModifier(cornerRadius: cornerRadius, glowColor: glowColor, padding: padding))
    }
}

// MARK: - Legacy Helper Card Compatibility
public struct CosmicCard<Content: View>: View {
    public let padding: CGFloat
    public let cornerRadius: CGFloat
    public let content: Content
    
    public init(padding: CGFloat = 16, cornerRadius: CGFloat = 18, @ViewBuilder content: () -> Content) {
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

// MARK: - Cosmic Primary Button
public struct CosmicPrimaryButton: View {
    public let title: String
    public let action: () -> Void
    
    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(CosmosTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [CosmosTheme.cosmicPurple, Color(hex: "#6344E0")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: CosmosTheme.cosmicPurple.opacity(0.4), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.cosmicPrimaryPressable)
    }
}
