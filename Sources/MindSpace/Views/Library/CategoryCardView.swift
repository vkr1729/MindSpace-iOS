import SwiftUI

/// Planetary category card matching Screen 2 of the canonical mockup.
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
            Button(action: action) {
                cardContent
            }
            .buttonStyle(.plain)
        } else {
            cardContent
        }
    }
    
    private var cardContent: some View {
        HStack(spacing: 16) {
            // Planetary Art
            CelestialPlanetView(style: planetStyle, size: 54, hasRings: planetStyle == .purpleRinged)
                .frame(width: 60, height: 60)
            
            // Titles and Session Count
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .lineLimit(1)
                
                Text(sessionCountText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(planetStyle.primaryColor)
                    .padding(.top, 2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(CosmosTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(CosmosTheme.spaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
