import SwiftUI

public enum PlanetStyle: String, CaseIterable, Sendable {
    case purpleRinged   // Foundation & Basics
    case auroraTeal     // Health & Wellbeing
    case solarCoral     // Happiness & Relationships
    case electricBlue   // Work & Focus
    case crescentMoon   // Sleep & Rest
    case goldenSun      // Orbit Milestone & Completion
    case deepLavender   // Students
    case brave          // Brave & Resilience
    case sport          // Sport & Performance
    case pro            // MindSpace Pro
    case deepCosmos     // Default Deep Space
    
    public var assetImageName: String {
        switch self {
        case .purpleRinged: return "planet_foundation"
        case .auroraTeal: return "planet_health"
        case .solarCoral: return "planet_happiness"
        case .electricBlue: return "planet_work"
        case .crescentMoon: return "planet_sleep"
        case .goldenSun: return "planet_pro"
        case .deepLavender: return "planet_students"
        case .brave: return "planet_brave"
        case .sport: return "planet_sport"
        case .pro, .deepCosmos: return "planet_pro"
        }
    }
    
    public var primaryColor: Color {
        switch self {
        case .purpleRinged: return CosmosTheme.cosmicPurple
        case .auroraTeal: return CosmosTheme.auroraTeal
        case .solarCoral: return CosmosTheme.solarCoral
        case .electricBlue: return CosmosTheme.celestialBlue
        case .crescentMoon: return CosmosTheme.moonLavender
        case .goldenSun: return CosmosTheme.starlightGold
        case .deepLavender: return CosmosTheme.moonLavender
        case .brave: return CosmosTheme.solarCoral
        case .sport: return CosmosTheme.auroraTeal
        case .pro: return CosmosTheme.starlightGold
        case .deepCosmos: return CosmosTheme.cosmicPurple
        }
    }
    
    public var secondaryColor: Color {
        switch self {
        case .purpleRinged: return Color(hex: "#4F32A5")
        case .auroraTeal: return Color(hex: "#227B63")
        case .solarCoral: return Color(hex: "#C84942")
        case .electricBlue: return Color(hex: "#1E40AF")
        case .crescentMoon: return Color(hex: "#312E81")
        case .goldenSun: return Color(hex: "#D97706")
        case .deepLavender: return Color(hex: "#5B21B6")
        case .brave: return Color(hex: "#881337")
        case .sport: return Color(hex: "#0E7490")
        case .pro: return Color(hex: "#78350F")
        case .deepCosmos: return Color(hex: "#1E1B4B")
        }
    }
}

public typealias CelestialPlanetStyle = PlanetStyle

/// A procedural 3D celestial planet view with atmospheric glow, surface texture gradients, and planetary rings.
public struct CelestialPlanetView: View {
    public let style: PlanetStyle
    public let size: CGFloat
    public let hasRings: Bool
    public let isAnimated: Bool
    
    @State private var rotationAngle: Double = 0
    @State private var floatingOffset: CGFloat = 0
    
    public init(
        style: PlanetStyle = .purpleRinged,
        size: CGFloat = 160,
        hasRings: Bool = true,
        isAnimated: Bool = false
    ) {
        self.style = style
        self.size = size
        self.hasRings = hasRings
        self.isAnimated = isAnimated
    }
    
    public var body: some View {
        ZStack {
            // Ambient Atmospheric Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            style.primaryColor.opacity(0.45),
                            style.primaryColor.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.25,
                        endRadius: size * 0.75
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
            
            #if os(iOS)
            if UIImage(named: style.assetImageName) != nil {
                Image(style.assetImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 1.25, height: size * 1.25)
                    .shadow(color: style.primaryColor.opacity(0.4), radius: size * 0.15, x: 0, y: 4)
            } else {
                proceduralPlanetBody
            }
            #else
            proceduralPlanetBody
            #endif
        }
        .offset(y: floatingOffset)
        .onAppear {
            if isAnimated {
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                    floatingOffset = -6
                }
            }
        }
    }
    
    @ViewBuilder
    private var proceduralPlanetBody: some View {
        ZStack {
            // Planetary Rings (Back layer if ringed)
            if hasRings && style == .purpleRinged {
                Ellipse()
                    .stroke(
                        LinearGradient(
                            colors: [
                                style.primaryColor.opacity(0.8),
                                CosmosTheme.starlightGold.opacity(0.5),
                                style.secondaryColor.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.07
                    )
                    .frame(width: size * 1.6, height: size * 0.45)
                    .rotationEffect(.degrees(-22))
                    .opacity(0.85)
            }
            
            // Central Sphere Body
            if style == .crescentMoon {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [style.primaryColor, style.secondaryColor],
                                center: .topLeading,
                                startRadius: size * 0.1,
                                endRadius: size * 0.6
                            )
                        )
                        .frame(width: size, height: size)
                    
                    // Shadow overlay to carve crescent
                    Circle()
                        .fill(CosmosTheme.spaceBackground)
                        .frame(width: size * 0.88, height: size * 0.88)
                        .offset(x: size * 0.22, y: -size * 0.15)
                }
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                style.primaryColor.opacity(0.95),
                                style.secondaryColor,
                                Color(hex: "#060911")
                            ],
                            center: UnitPoint(x: 0.32, y: 0.30),
                            startRadius: size * 0.05,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        // Atmospheric Rim Light
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        style.primaryColor.opacity(0.4),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: size * 0.03
                            )
                    )
                    .shadow(color: style.primaryColor.opacity(0.4), radius: size * 0.15, x: 0, y: 4)
            }
            
            // Front layer of Planetary Rings (for 3D occlusion)
            if hasRings && style == .purpleRinged {
                Ellipse()
                    .trim(from: 0.0, to: 0.5)
                    .stroke(
                        LinearGradient(
                            colors: [
                                style.primaryColor,
                                CosmosTheme.starlightGold.opacity(0.7),
                                style.secondaryColor.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.07
                    )
                    .frame(width: size * 1.6, height: size * 0.45)
                    .rotationEffect(.degrees(-22))
                    .offset(y: size * 0.02)
            }
        }
    }
}
