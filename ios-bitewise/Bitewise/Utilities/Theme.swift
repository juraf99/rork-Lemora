import SwiftUI

/// Bitewise design tokens. Colors are derived from the lemon mascot logo.
enum BW {
    static let canvas = Color(hex: 0xFBF7EE)
    static let card = Color.white
    static let beige = Color(hex: 0xEFE6D6)
    static let beigeSoft = Color(hex: 0xF5EFE3)
    static let lemon = Color(hex: 0xF5D33B)
    static let lemonSoft = Color(hex: 0xFFF4C7)
    static let amber = Color(hex: 0xC99400)
    static let ink = Color(hex: 0x3A3220)
    static let inkSecondary = Color(hex: 0x7A705C)
    static let leaf = Color(hex: 0x6FA43F)
    static let leafDeep = Color(hex: 0x4A7D28)
    static let leafSoft = Color(hex: 0xE7F0DB)
    static let outline = Color(hex: 0xA9BAC9)
    static let hairline = Color(hex: 0xE8E0D0)
    static let danger = Color(hex: 0xC8553D)

    static let cardRadius: CGFloat = 22
    static let heroRadius: CGFloat = 30
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

extension Font {
    /// Rounded display typography that still scales with Dynamic Type.
    static func bw(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

struct BWCardModifier: ViewModifier {
    var radius: CGFloat = BW.cardRadius
    var fill: Color = BW.card

    func body(content: Content) -> some View {
        content
            .background(fill, in: .rect(cornerRadius: radius))
            .shadow(color: BW.ink.opacity(0.06), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func bwCard(radius: CGFloat = BW.cardRadius, fill: Color = BW.card) -> some View {
        modifier(BWCardModifier(radius: radius, fill: fill))
    }
}

struct BWPrimaryButtonStyle: ButtonStyle {
    var fill: Color = BW.lemon
    var foreground: Color = BW.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bw(.headline))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(fill, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct BWSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bw(.headline, weight: .semibold))
            .foregroundStyle(BW.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(BW.card, in: .capsule)
            .overlay(Capsule().strokeBorder(BW.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct BWPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

nonisolated enum Money {
    static func format(_ value: Double) -> String {
        value.formatted(.currency(code: "CAD").presentation(.narrow))
    }
}
