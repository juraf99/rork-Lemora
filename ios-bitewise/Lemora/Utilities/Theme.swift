import SwiftUI
import CoreText

/// Lemora design tokens. Deep forest ink + lemon accent on warm cream, matched to the
/// Lemora wordmark and the paywall reference.
enum BW {
    static let canvas = Color(hex: 0xFAF6ED)
    static let card = Color.white
    static let beige = Color(hex: 0xEFE6D6)
    static let beigeSoft = Color(hex: 0xF3EDE1)
    static let lemon = Color(hex: 0xF0D45B)
    static let lemonBright = Color(hex: 0xF7E07A)
    static let lemonSoft = Color(hex: 0xFFF4C7)
    static let sun = Color(hex: 0xFAF0BF)
    static let amber = Color(hex: 0xC99400)
    static let apricot = Color(hex: 0xE6A463)
    static let ink = Color(hex: 0x1B352C)
    static let inkSecondary = Color(hex: 0x626B64)
    static let leaf = Color(hex: 0x6FA43F)
    static let leafDeep = Color(hex: 0x3F7F3A)
    static let leafSoft = Color(hex: 0xE7F0DB)
    static let outline = Color(hex: 0xA9B3AC)
    static let hairline = Color(hex: 0xE9E1D1)
    static let danger = Color(hex: 0xC8553D)
    /// Zesty's skin tone, used for eyelids when blinking.
    static let zestSkin = Color(hex: 0xFEDE22)

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

/// Figtree matches the geometric, soft personality of the Lemora wordmark and covers French diacritics.
nonisolated enum LemoraFont {
    static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .black: "Figtree-Black"
        case .heavy: "Figtree-ExtraBold"
        case .bold: "Figtree-Bold"
        case .semibold: "Figtree-SemiBold"
        case .medium: "Figtree-Medium"
        default: "Figtree-Regular"
        }
    }

    static func size(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }

    /// Registers bundled Figtree files so `Font.custom` resolves them.
    static func registerAll() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// Lemora UI typography that scales with Dynamic Type.
    static func bw(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .custom(LemoraFont.name(for: weight), size: LemoraFont.size(for: style), relativeTo: style)
    }

    /// Display sizes (big numbers, hero headlines) that still scale with Dynamic Type.
    static func bw(size: CGFloat, weight: Font.Weight = .bold, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom(LemoraFont.name(for: weight), size: size, relativeTo: style)
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
            .font(.bw(.headline, weight: .heavy))
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

    static func format(_ value: Double?) -> String {
        value.map(format) ?? "—"
    }
}
