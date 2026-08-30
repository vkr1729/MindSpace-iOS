import SwiftUI

/// Compact, image-free category card for scan-heavy library surfaces.
public struct CategoryCardView: View {
    public let title: String
    public let subtitle: String
    public let sessionCountText: String
    public let action: (() -> Void)?
    
    public init(
        title: String,
        subtitle: String,
        sessionCountText: String,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.sessionCountText = sessionCountText
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
            .buttonStyle(.mindSpacePressable)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens category")
        } else {
            cardContent
        }
    }
    
    private var cardContent: some View {
        HStack(spacing: 16) {
            MindSpaceCourseBadge(name: title, size: 52)
            
            // Titles and Session Count
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(MindSpaceTheme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(MindSpaceTheme.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .accessibilityHidden(true)
                    Text(sessionCountText)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(MindSpaceTheme.accent(for: title))
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(MindSpaceTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                MindSpaceTheme.surface
                LinearGradient(
                    colors: [MindSpaceTheme.accent(for: title).opacity(0.06), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MindSpaceTheme.divider, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(minHeight: 44)
    }
}
