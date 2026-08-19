import SwiftUI

/// View displaying individual standalone meditation singles.
public struct SinglesListView: View {
    public let category: SinglesCategory
    public let onSelectSession: (SingleSession) -> Void
    
    public init(category: SinglesCategory, onSelectSession: @escaping (SingleSession) -> Void) {
        self.category = category
        self.onSelectSession = onSelectSession
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header Banner
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                    
                    Text(category.description)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                // Track List
                LazyVStack(spacing: 10) {
                    ForEach(category.sessions) { session in
                        Button(action: {
                            onSelectSession(session)
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: category.iconName.isEmpty ? "sparkles" : category.iconName)
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: category.colorHex))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle().fill(Color(hex: category.colorHex).opacity(0.15))
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                    
                                    if let sub = session.subCategory {
                                        Text(sub)
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundColor(CosmosTheme.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(session.formattedDuration)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                                
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(CosmosTheme.cosmicPurple)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(CosmosTheme.spaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer(minLength: 80)
            }
        }
        .background(CosmosTheme.spaceBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
