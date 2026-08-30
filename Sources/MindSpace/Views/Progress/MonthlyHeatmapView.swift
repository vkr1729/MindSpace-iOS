import SwiftUI

/// Monthly activity heatmap with four explicit intensity levels.
/// Reference: Mock Screen Codex.png (Screen 6: Your journey)
public struct MonthlyHeatmapView: View {
    public let activeDates: Set<String>
    public let dailyMinutes: [String: Int]
    
    @State private var currentMonthDate = Date()
    
    public init(activeDates: Set<String>, dailyMinutes: [String: Int]) {
        self.activeDates = activeDates
        self.dailyMinutes = dailyMinutes
    }
    
    private var calendar: Calendar { .current }
    
    private var monthYearTitle: String {
        DateFormatterCache.monthYearString(from: currentMonthDate)
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonthDate),
              let firstDayWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }
        
        let daysInMonthCount = calendar.range(of: .day, in: .month, for: currentMonthDate)?.count ?? 30
        
        // Convert Sunday (1) -> Monday (1) based index (Monday=1, Sunday=7)
        let offset = (firstDayWeekday + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in 0..<daysInMonthCount {
            if let date = calendar.date(byAdding: .day, value: day, to: monthInterval.start) {
                days.append(date)
            }
        }
        
        // Pad end of grid to complete 7-day row
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    public var body: some View {
        MindSpaceCard(padding: 16) {
            VStack(spacing: 14) {
                // Month Header & Navigation
                HStack {
                    Text(monthYearTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(MindSpaceTheme.textPrimary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button(action: { changeMonth(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(MindSpaceTheme.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(MindSpaceTheme.divider)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Previous month")
                        
                        Button(action: { changeMonth(by: 1) }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(MindSpaceTheme.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(MindSpaceTheme.divider)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Next month")
                    }
                }
                
                // Weekday Headers (M T W T F S S)
                HStack {
                    ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(MindSpaceTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Grid of Activity Dots
                let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(0..<daysInMonth.count, id: \.self) { index in
                        if let date = daysInMonth[index] {
                            let dayString = dateKey(for: date)
                            let minutes = dailyMinutes[dayString] ?? 0
                            dayDot(minutes: minutes, date: date)
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                
                // Heatmap Legend (Less -> More)
                HStack(spacing: 6) {
                    Text("Less")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MindSpaceTheme.textSecondary)
                    
                    legendDot(color: MindSpaceTheme.divider)
                    legendDot(color: MindSpaceTheme.accent.opacity(0.4))
                    legendDot(color: MindSpaceTheme.accent)
                    legendDot(color: MindSpaceTheme.warning)
                    
                    Text("More")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MindSpaceTheme.textSecondary)
                }
                .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Practice activity for \(monthYearTitle)")
    }
    
    @ViewBuilder
    private func dayDot(minutes: Int, date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        
        ZStack {
            Circle()
                .fill(dotColor(for: minutes))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(isToday ? MindSpaceTheme.warning : Color.clear, lineWidth: 1.5)
                )
            
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(minutes > 0 ? MindSpaceTheme.background : MindSpaceTheme.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DateFormatterCache.dayKey(from: date))
        .accessibilityValue(minutes == 0 ? "No practice" : "\(minutes) mindful minutes")
    }
    
    @ViewBuilder
    private func legendDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }
    
    private func dotColor(for minutes: Int) -> Color {
        if minutes == 0 {
            return MindSpaceTheme.divider.opacity(0.5)
        } else if minutes < 10 {
            return MindSpaceTheme.accent.opacity(0.5)
        } else if minutes < 20 {
            return MindSpaceTheme.accent
        } else {
            return MindSpaceTheme.warning
        }
    }
    
    private func dateKey(for date: Date) -> String {
        DateFormatterCache.dayKey(from: date)
    }
    
    private func changeMonth(by delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: currentMonthDate) {
            currentMonthDate = newMonth
        }
    }
}
