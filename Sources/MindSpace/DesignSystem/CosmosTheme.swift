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
