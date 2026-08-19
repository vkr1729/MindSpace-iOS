import SwiftUI

public struct DailyJourneyItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let durationLabel: String
    public let isPrimaryAction: Bool
    public var isCompleted: Bool
    public let playableTrack: PlayableTrack?
    
    public init(
        id: String,
        title: String,
        durationLabel: String,
        isPrimaryAction: Bool = false,
        isCompleted: Bool = false,
        playableTrack: PlayableTrack? = nil
    ) {
        self.id = id
        self.title = title
        self.durationLabel = durationLabel
        self.isPrimaryAction = isPrimaryAction
        self.isCompleted = isCompleted
        self.playableTrack = playableTrack
    }
}

/// 3-Item Daily Journey checklist component on the Today screen.
public struct DailyJourneyView: View {
    @Binding public var items: [DailyJourneyItem]
    public let onSelectTrack: (PlayableTrack) -> Void
    
    public init(
        items: Binding<[DailyJourneyItem]>,
        onSelectTrack: @escaping (PlayableTrack) -> Void
    ) {
        self._items = items
        self.onSelectTrack = onSelectTrack
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Journey")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(CosmosTheme.textPrimary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 10) {
                ForEach($items) { $item in
                    journeyRow(for: $item)
                }
            }
        }
    }
    
    @ViewBuilder
    private func journeyRow(for item: Binding<DailyJourneyItem>) -> some View {
        let currentItem = item.wrappedValue
        HStack(spacing: 14) {
            // Checkbox Icon
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    item.wrappedValue.isCompleted.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(currentItem.isCompleted ? CosmosTheme.starlightGold : CosmosTheme.spaceCardBorder, lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(currentItem.isCompleted ? CosmosTheme.starlightGold : Color.clear)
                        )
                    
                    if currentItem.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(CosmosTheme.spaceBackground)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Text Details
            VStack(alignment: .leading, spacing: 2) {
                Text(currentItem.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(currentItem.isCompleted ? CosmosTheme.textSecondary : CosmosTheme.textPrimary)
                    .strikethrough(currentItem.isCompleted, color: CosmosTheme.textSecondary)
                
                Text(currentItem.durationLabel)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
            }
            
            Spacer()
            
            // Quick Continue Button if Primary Action
            if currentItem.isPrimaryAction && !currentItem.isCompleted {
                Button(action: {
                    if let track = currentItem.playableTrack {
                        onSelectTrack(track)
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(CosmosTheme.cosmicPurple)
                        .clipShape(Capsule())
                        .shadow(color: CosmosTheme.cosmicPurple.opacity(0.4), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            } else if let track = currentItem.playableTrack {
                Button(action: {
                    onSelectTrack(track)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(CosmosTheme.moonLavender)
                }
                .buttonStyle(.plain)
            }
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
}
