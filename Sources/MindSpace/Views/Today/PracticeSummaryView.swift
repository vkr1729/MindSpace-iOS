import SwiftUI

/// A plain-language summary of recent practice. Progress is repeated in text so
/// color and shape are never the only way to understand it.
public struct PracticeSummaryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let currentStreak: Int
    public let milestoneDays: Int
    public let totalMinutes: Int
    public let passesAvailable: Int

    @State private var displayedProgress = 0.0

    public init(
        currentStreak: Int,
        milestoneDays: Int,
        totalMinutes: Int,
        passesAvailable: Int
    ) {
        self.currentStreak = currentStreak
        self.milestoneDays = max(1, milestoneDays)
        self.totalMinutes = totalMinutes
        self.passesAvailable = passesAvailable
    }

    private var progress: Double {
        min(1, Double(currentStreak) / Double(milestoneDays))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Practice streak")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MindSpaceTheme.textSecondary)

                    Text("\(currentStreak) \(currentStreak == 1 ? "day" : "days")")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(MindSpaceTheme.textPrimary)
                }

                Spacer(minLength: 16)

                Text("Next: \(milestoneDays) days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MindSpaceTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(MindSpaceTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
            }

            ProgressView(value: displayedProgress)
                .tint(MindSpaceTheme.accent)
                .accessibilityLabel("Practice streak progress")
                .accessibilityValue("\(currentStreak) of \(milestoneDays) days")

            HStack(spacing: 20) {
                Label("\(totalMinutes) mindful min", systemImage: "clock")
                if passesAvailable > 0 {
                    Label("\(passesAvailable) compassion \(passesAvailable == 1 ? "pass" : "passes")", systemImage: "heart")
                }
            }
            .font(.caption)
            .foregroundStyle(MindSpaceTheme.textSecondary)
        }
        .mindSpaceEmphasisStyle(accentColor: MindSpaceTheme.accent)
        .accessibilityElement(children: .combine)
        .onAppear {
            if reduceMotion {
                displayedProgress = progress
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    displayedProgress = progress
                }
            }
        }
        .onChange(of: currentStreak) { _, _ in
            if reduceMotion {
                displayedProgress = progress
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    displayedProgress = progress
                }
            }
        }
    }
}
