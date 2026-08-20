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

/// 3-Item Daily Journey checklist component on the Today screen with tactile interactions.
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily Journey")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                Spacer()
                
                let completedCount = items.filter { $0.isCompleted }.count
                Text("\(completedCount)/\(items.count) Completed")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(completedCount == items.count ? CosmosTheme.starlightGold : CosmosTheme.moonLavender)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(CosmosTheme.spacePill)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
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
            // Real Completion Checkmark Indicator
            ZStack {
                Circle()
                    .stroke(currentItem.isCompleted ? CosmosTheme.starlightGold : CosmosTheme.spaceCardBorder, lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(currentItem.isCompleted ? CosmosTheme.starlightGold : Color.clear)
                    )
                    .shadow(color: currentItem.isCompleted ? CosmosTheme.starlightGold.opacity(0.4) : Color.clear, radius: 4)
                
                if currentItem.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(CosmosTheme.spaceBackground)
                }
            }
            
            // Text Details
            VStack(alignment: .leading, spacing: 3) {
                Text(currentItem.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
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
                    HapticService.shared.medium()
                    if let track = currentItem.playableTrack {
                        onSelectTrack(track)
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Continue")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [CosmosTheme.cosmicPurple, Color(hex: "#6344E0")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: CosmosTheme.cosmicPurple.opacity(0.4), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.cosmicPressable)
            } else if let track = currentItem.playableTrack {
                Button(action: {
                    HapticService.shared.medium()
                    onSelectTrack(track)
                }) {
                    Image(systemName: currentItem.isCompleted ? "arrow.counterclockwise.circle.fill" : "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(currentItem.isCompleted ? CosmosTheme.textSecondary : CosmosTheme.moonLavender)
                }
                .buttonStyle(.cosmicPressable)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                CosmosTheme.spaceCard
                if currentItem.isPrimaryAction && !currentItem.isCompleted {
                    CosmosTheme.cosmicPurple.opacity(0.08)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    currentItem.isPrimaryAction && !currentItem.isCompleted ? CosmosTheme.cosmicPurple.opacity(0.4) : CosmosTheme.spaceCardBorder,
                    lineWidth: 1
                )
        )
    }
}
