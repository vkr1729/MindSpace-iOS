import SwiftUI

/// Planetary category card matching Screen 2 with ambient illumination.
public struct CategoryCardView: View {
    public let title: String
    public let subtitle: String
    public let sessionCountText: String
    public let planetStyle: PlanetStyle
    public let action: (() -> Void)?
    
    public init(
        title: String,
        subtitle: String,
        sessionCountText: String,
        planetStyle: PlanetStyle = .purpleRinged,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.sessionCountText = sessionCountText
        self.planetStyle = planetStyle
        self.action = action
    }
    
    public var body: some View {
        if let action = action {
            Button(action: {
                HapticService.shared.light()
                action()
            }) {
                cardContent
            }
            .buttonStyle(.cosmicPressable)
        } else {
            cardContent
        }
    }
    
    private var cardContent: some View {
        HStack(spacing: 16) {
            // Planetary Art with subtle ambient aura
            ZStack {
                Circle()
                    .fill(planetStyle.primaryColor.opacity(0.18))
                    .frame(width: 58, height: 58)
                    .blur(radius: 6)
                
                CelestialPlanetView(style: planetStyle, size: 52, hasRings: planetStyle == .purpleRinged)
                    .frame(width: 58, height: 58)
            }
            
            // Titles and Session Count
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(planetStyle.primaryColor)
                        .frame(width: 5, height: 5)
                    Text(sessionCountText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(planetStyle.primaryColor)
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(CosmosTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                CosmosTheme.spaceCard
                LinearGradient(
                    colors: [planetStyle.primaryColor.opacity(0.06), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
