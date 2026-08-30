import SwiftUI

public extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&value)

        let alpha: UInt64
        let red: UInt64
        let green: UInt64
        let blue: UInt64
        switch cleanHex.count {
        case 3:
            (alpha, red, green, blue) = (255, (value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6:
            (alpha, red, green, blue) = (255, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
        case 8:
            (alpha, red, green, blue) = ((value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
        default:
            (alpha, red, green, blue) = (255, 139, 202, 183)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

/// Quiet Native visual system. It is intentionally small: semantic color,
/// readable surfaces, native typography, and reusable interaction primitives.
public enum MindSpaceTheme {
    public static let background = Color(hex: "#090D0C")
    public static let surface = Color(hex: "#111715")
    public static let elevatedSurface = Color(hex: "#18201D")
    public static let divider = Color(hex: "#26312D")
    public static let materialFallback = Color(hex: "#1C2622")

    public static let accent = Color(hex: "#8BCAB7")
    public static let accentPressed = Color(hex: "#72B4A1")
    public static let success = Color(hex: "#8BCAB7")
    public static let completion = Color(hex: "#B7D6C8")
    public static let warning = Color(hex: "#D6BD92")
    public static let danger = Color(hex: "#EF9D9D")
    public static let focus = Color(hex: "#8CB9C4")
    public static let secondaryAccent = Color(hex: "#AAB8AE")

    public static let textPrimary = Color(hex: "#F2F7F4")
    public static let textSecondary = Color(hex: "#96A49E")
    public static let textDisabled = Color(hex: "#65706B")

    public static let sleepBackground = Color(hex: "#050706")
    public static let sleepSurface = Color(hex: "#0D1210")
    public static let sleepAccent = Color(hex: "#C7B993")

    public static func accent(for contentName: String) -> Color {
        let value = contentName.lowercased()
        if value.contains("sleep") || value.contains("night") || value.contains("unwind") {
            return secondaryAccent
        }
        if value.contains("health") || value.contains("anxiety") || value.contains("stress") || value.contains("healing") {
            return success
        }
        if value.contains("work") || value.contains("focus") || value.contains("performance") || value.contains("student") {
            return focus
        }
        if value.contains("sos") || value.contains("reset") || value.contains("panic") {
            return danger
        }
        if value.contains("brave") || value.contains("compassion") || value.contains("self-esteem") {
            return warning
        }
        return accent
    }

    public static func symbolName(for contentName: String) -> String {
        let value = contentName.lowercased()
        if value.contains("sleep") || value.contains("night") || value.contains("unwind") { return "bed.double.fill" }
        if value.contains("health") || value.contains("anxiety") || value.contains("stress") { return "waveform.path.ecg" }
        if value.contains("work") || value.contains("focus") || value.contains("student") { return "scope" }
        if value.contains("sos") || value.contains("panic") { return "lifepreserver.fill" }
        if value.contains("sport") || value.contains("performance") { return "figure.mind.and.body" }
        if value.contains("relationship") || value.contains("kindness") || value.contains("compassion") { return "heart.fill" }
        return "circle.dotted"
    }
}

public struct MindSpacePressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public enum HapticFeedbackType {
        case light
        case medium
        case soft
        case none
    }

    public let hapticType: HapticFeedbackType

    public init(hapticType: HapticFeedbackType = .light) {
        self.hapticType = hapticType
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed else { return }
                switch hapticType {
                case .light: HapticService.shared.light()
                case .medium: HapticService.shared.medium()
                case .soft: HapticService.shared.soft()
                case .none: break
                }
            }
    }
}

public extension ButtonStyle where Self == MindSpacePressableButtonStyle {
    static var mindSpacePressable: MindSpacePressableButtonStyle {
        MindSpacePressableButtonStyle(hapticType: .light)
    }

    static var mindSpacePrimaryPressable: MindSpacePressableButtonStyle {
        MindSpacePressableButtonStyle(hapticType: .medium)
    }
}

public struct MindSpaceCardModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let borderColor: Color
    public let padding: CGFloat

    public init(cornerRadius: CGFloat = 18, borderColor: Color = MindSpaceTheme.divider, padding: CGFloat = 16) {
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(MindSpaceTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
                    .accessibilityHidden(true)
            )
    }
}

public struct MindSpaceEmphasisModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let accentColor: Color
    public let padding: CGFloat

    public init(cornerRadius: CGFloat = 24, accentColor: Color = MindSpaceTheme.accent, padding: CGFloat = 20) {
        self.cornerRadius = cornerRadius
        self.accentColor = accentColor
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    MindSpaceTheme.surface
                    LinearGradient(
                        colors: [accentColor.opacity(0.10), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .accessibilityHidden(true)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MindSpaceTheme.divider, lineWidth: 1)
                    .accessibilityHidden(true)
            )
    }
}

public extension View {
    func mindSpaceCardStyle(
        cornerRadius: CGFloat = 18,
        borderColor: Color = MindSpaceTheme.divider,
        padding: CGFloat = 16
    ) -> some View {
        modifier(MindSpaceCardModifier(cornerRadius: cornerRadius, borderColor: borderColor, padding: padding))
    }

    func mindSpaceEmphasisStyle(
        cornerRadius: CGFloat = 24,
        accentColor: Color = MindSpaceTheme.accent,
        padding: CGFloat = 20
    ) -> some View {
        modifier(MindSpaceEmphasisModifier(cornerRadius: cornerRadius, accentColor: accentColor, padding: padding))
    }
}

public struct MindSpaceCard<Content: View>: View {
    public let padding: CGFloat
    public let cornerRadius: CGFloat
    public let content: Content

    public init(padding: CGFloat = 16, cornerRadius: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content.mindSpaceCardStyle(cornerRadius: cornerRadius, padding: padding)
    }
}

public struct MindSpacePrimaryButton: View {
    public let title: String
    public let systemImage: String?
    public let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(MindSpaceTheme.background)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(MindSpaceTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.mindSpacePrimaryPressable)
        .accessibilityLabel(title)
    }
}

public struct MindSpaceCourseBadge: View {
    public let name: String
    public let size: CGFloat

    public init(name: String, size: CGFloat = 44) {
        self.name = name
        self.size = max(44, size)
    }

    public var body: some View {
        Image(systemName: MindSpaceTheme.symbolName(for: name))
            .font(.system(size: size * 0.40, weight: .semibold))
            .foregroundStyle(MindSpaceTheme.accent(for: name))
            .frame(width: size, height: size)
            .background(MindSpaceTheme.accent(for: name).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.30, style: .continuous))
            .accessibilityHidden(true)
    }
}

public struct FilterChip: View {
    public let title: String
    public let isSelected: Bool
    public let action: () -> Void

    public init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? MindSpaceTheme.background : MindSpaceTheme.textSecondary)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(isSelected ? MindSpaceTheme.accent : MindSpaceTheme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : MindSpaceTheme.divider, lineWidth: 1)
                        .accessibilityHidden(true)
                )
        }
        .buttonStyle(.mindSpacePressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
