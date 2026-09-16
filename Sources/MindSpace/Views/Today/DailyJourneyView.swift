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

/// Three concise daily suggestions with one unmistakable primary action.
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
            HStack {
                Text("Daily journey")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MindSpaceTheme.textPrimary)
                
                Spacer()
                
                let completedCount = items.filter { $0.isCompleted }.count
                Text("\(completedCount) of \(items.count) complete")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(completedCount == items.count ? MindSpaceTheme.completion : MindSpaceTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(MindSpaceTheme.elevatedSurface)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach($items) { $item in
                    journeyRow(for: $item)
                    if item.id != items.last?.id {
                        Divider().overlay(MindSpaceTheme.divider)
                    }
                }
            }
            .mindSpaceCardStyle(padding: 0)
        }
    }
    
    @ViewBuilder
    private func journeyRow(for item: Binding<DailyJourneyItem>) -> some View {
        let currentItem = item.wrappedValue
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(currentItem.isCompleted ? MindSpaceTheme.completion : MindSpaceTheme.divider, lineWidth: 1.5)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(currentItem.isCompleted ? MindSpaceTheme.completion : Color.clear)
                    )
                
                if currentItem.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MindSpaceTheme.background)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(currentItem.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(currentItem.isCompleted ? MindSpaceTheme.textSecondary : MindSpaceTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(currentItem.durationLabel)
                    .font(.subheadline)
                    .foregroundStyle(MindSpaceTheme.textSecondary)
            }
            
            Spacer()
            
            if currentItem.isPrimaryAction && !currentItem.isCompleted {
                Button(action: {
                    HapticService.shared.medium()
                    if let track = currentItem.playableTrack {
                        onSelectTrack(track)
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Continue")
                            .font(.subheadline.weight(.bold))
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(MindSpaceTheme.background)
                    .frame(minWidth: 100, minHeight: 44)
                    .padding(.horizontal, 10)
                    .background(MindSpaceTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.mindSpacePrimaryPressable)
                .accessibilityLabel("Continue \(currentItem.title)")
                .accessibilityIdentifier("today.continue")
            } else if let track = currentItem.playableTrack {
                Button(action: {
                    HapticService.shared.medium()
                    onSelectTrack(track)
                }) {
                    Image(systemName: currentItem.isCompleted ? "arrow.counterclockwise" : "play.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(currentItem.isCompleted ? MindSpaceTheme.textSecondary : MindSpaceTheme.accent)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.mindSpacePressable)
                .accessibilityLabel(currentItem.isCompleted ? "Play \(currentItem.title) again" : "Play \(currentItem.title)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(currentItem.isPrimaryAction && !currentItem.isCompleted ? MindSpaceTheme.accent.opacity(0.05) : Color.clear)
    }
}
