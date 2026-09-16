import Foundation

public enum AppTab: String, CaseIterable, Identifiable {
    case today, library, progress, settings
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .today: "Today"
        case .library: "Library"
        case .progress: "Progress"
        case .settings: "Settings"
        }
    }
    public var iconName: String {
        switch self {
        case .today: "sun.max.fill"
        case .library: "books.vertical.fill"
        case .progress: "chart.bar.fill"
        case .settings: "gearshape.fill"
        }
    }
}
