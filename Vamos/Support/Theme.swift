import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    static let vBackground = Color(light: 0xFBF6EE, dark: 0x15110D)
    static let vCard = Color(light: 0xFFFFFF, dark: 0x221C16)
    static let vSunken = Color(light: 0xF2EBDF, dark: 0x2C251E)
    static let vLine = Color(light: 0xE6DCCB, dark: 0x3A3129)
    static let vRojo = Color(light: 0xC8102E, dark: 0xE8475A)
    static let vOro = Color(light: 0xF1BF00, dark: 0xF5C931)
    static let vOK = Color(light: 0x2E9E5B, dark: 0x4CC27F)
    static let vBad = Color(light: 0xD7263D, dark: 0xF06275)
    static let vMuted = Color(light: 0x8A7F70, dark: 0xA39886)

    static func unit(_ name: String) -> Color {
        switch name {
        case "azul": return Color(light: 0x1F5FA8, dark: 0x4D8FDB)
        case "verde": return Color(light: 0x2E8B57, dark: 0x4FB37C)
        case "oro": return Color(light: 0xC98A00, dark: 0xE2A72A)
        case "morado": return Color(light: 0x6A3FA0, dark: 0x9C7AD6)
        case "tinto": return Color(light: 0x7A1F3D, dark: 0xC0587A)
        default: return .vRojo
        }
    }
}

extension Font {
    /// Spanish text is set in a serif face so it stands apart from the Chinese UI.
    static func spanish(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

// MARK: - Buttons

/// Chunky button with a "pressed down" bottom edge.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = .vRojo
    var foreground: Color = .white
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && enabled
        return configuration.label
            .font(.headline)
            .foregroundColor(enabled ? foreground : .vMuted)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(enabled ? color : Color.vSunken)
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(enabled ? color.opacity(0.55) : Color.vLine)
                    .offset(y: pressed ? 0 : 4)
            )
            .offset(y: pressed ? 4 : 0)
            .padding(.bottom, 4)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Card-like tappable option.
struct OptionButtonStyle: ButtonStyle {
    var border: Color
    var fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(border, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.vCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.vLine, lineWidth: 1)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

// MARK: - Haptics

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
