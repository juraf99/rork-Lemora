import SwiftUI

/// Visual tokens for the v2 onboarding, taken 1:1 from the approved HTML design.
enum OB {
    static let ink = Color(hex: 0x10362B)
    static let cream = Color(hex: 0xFBF6EC)
    static let lemon = Color(hex: 0xF6D23C)
    static let pill = Color(hex: 0xF1EADB)
    static let track = Color(hex: 0xE9E2D2)
    static let sub = Color(hex: 0x6B726A)
    static let muted = Color(hex: 0x5F6B63)
    static let faint = Color(hex: 0x8A8F86)
    static let border = Color(hex: 0xE3DCCB)
    static let inputBorder = Color(hex: 0xEFE8DA)
    static let green = Color(hex: 0x2F9E4F)
    static let mint = Color(hex: 0xEAF5E4)
    static let mintText = Color(hex: 0x2D5A2F)
    static let sunSoft = Color(hex: 0xFCF1BF)
    static let peach = Color(hex: 0xFDEBDD)
    static let selected = Color(hex: 0xFFFBEA)
    static let red = Color(hex: 0xC8412F)
    static let redSoft = Color(hex: 0xFFF1EE)
    static let redText = Color(hex: 0x8A3A2C)
    static let tileIcon = Color(hex: 0xF6F1E4)
    static let redIcon = Color(hex: 0xFFF4F1)
    static let divider = Color(hex: 0xF1EADD)
    static let glow = Color(hex: 0xFFF3C4)
    static let disabledText = Color(hex: 0xA09A8C)
    static let radioOff = Color(hex: 0xD9D3C5)
    static let orange = Color(hex: 0xF0913A)
    static let leaf = Color(hex: 0x7BB342)

    /// Figtree at an exact design size. `weight` follows CSS numbers (500...800).
    static func font(_ size: CGFloat, _ weight: Int = 700) -> Font {
        let name: String
        switch weight {
        case 800...: name = "Figtree-ExtraBold"
        case 700..<800: name = "Figtree-Bold"
        case 600..<700: name = "Figtree-SemiBold"
        case 500..<600: name = "Figtree-Medium"
        default: name = "Figtree-Regular"
        }
        return .custom(name, fixedSize: size)
    }

    /// CSS `radial-gradient(rx% ry% at 50% cy%, inner 0%, cream stop%)` on the cream page.
    static func sun(rx: CGFloat = 1.1, ry: CGFloat = 0.6, cy: CGFloat = 0.34, stop: CGFloat = 0.62, inner: Color = OB.glow) -> some View {
        GeometryReader { geo in
            EllipticalGradient(stops: [.init(color: inner, location: 0), .init(color: OB.cream, location: stop)],
                               center: .center, startRadiusFraction: 0, endRadiusFraction: 1)
                .frame(width: geo.size.width * rx * 2, height: geo.size.height * ry * 2)
                .position(x: geo.size.width / 2, y: geo.size.height * cy)
        }
        .background(OB.cream)
        .clipped()
        .ignoresSafeArea()
    }
}

// MARK: - Shared controls

struct OBBackButton: View {
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("‹")
                .font(OB.font(18, 700))
                .foregroundStyle(OB.ink)
                .frame(width: size, height: size)
                .background(OB.pill, in: .circle)
        }
        .buttonStyle(OBPress())
        .accessibilityLabel("Back")
    }
}

struct OBPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Yellow pill CTA. `height` nil means padding-driven (17 pt vertical padding, like the design).
struct OBPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    var height: CGFloat? = nil
    var fontSize: CGFloat = 17
    var shine: Bool = false
    var loading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if shine && enabled { OBSheen() }
                Text(title)
                    .font(OB.font(fontSize, 800))
                    .foregroundStyle(enabled ? OB.ink : OB.disabledText)
                    .opacity(loading ? 0 : 1)
                if loading { ProgressView().tint(OB.ink) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(.vertical, height == nil ? 17 : 0)
            .background(enabled ? OB.lemon : OB.track, in: .capsule)
            .clipShape(.capsule)
            .shadow(color: enabled ? OB.lemon.opacity(0.4) : .clear, radius: 8, x: 0, y: 6)
        }
        .buttonStyle(OBPress())
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }
}

/// Moving highlight across the paywall CTA (bwsheen).
struct OBSheen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            GeometryReader { geo in
                let t = tl.date.timeIntervalSinceReferenceDate
                let p = max(0, (t - 1).truncatingRemainder(dividingBy: 4.5)) / 4.5
                let k = min(1, p / 0.35)
                let e = k < 0.5 ? 2 * k * k : 1 - pow(-2 * k + 2, 2) / 2
                let w = geo.size.width * 0.34
                LinearGradient(colors: [.white.opacity(0), .white.opacity(0.6), .white.opacity(0)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: w, height: geo.size.height)
                    .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.36, d: 1, tx: 0, ty: 0))
                    .offset(x: -1.2 * w + e * 4.4 * w)
            }
        }
        .allowsHitTesting(false)
    }
}

struct OBCheck: View {
    let on: Bool
    var size: CGFloat = 22
    var red: Bool = false

    var body: some View {
        Text("✓")
            .font(OB.font(size * 0.5, 800))
            .foregroundStyle(on ? (red ? .white : OB.lemon) : .clear)
            .frame(width: size, height: size)
            .background(on ? (red ? OB.red : OB.ink) : OB.pill, in: .circle)
            .animation(.easeInOut(duration: 0.2), value: on)
    }
}

struct OBRadio: View {
    let on: Bool

    var body: some View {
        ZStack {
            Circle().fill(on ? OB.lemon : .white)
            Circle().strokeBorder(on ? OB.ink : OB.radioOff, lineWidth: on ? 7 : 2)
        }
        .frame(width: 22, height: 22)
        .animation(.easeInOut(duration: 0.2), value: on)
    }
}

extension View {
    /// `.card` from the design: white rounded card that turns cream-yellow with a lemon border when selected.
    func obCard(_ on: Bool, radius: CGFloat = 22) -> some View {
        self
            .background(on ? OB.selected : .white, in: .rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(on ? OB.lemon : .clear, lineWidth: 2))
            .shadow(color: on ? OB.lemon.opacity(0.25) : OB.ink.opacity(0.05), radius: on ? 7 : 5, x: 0, y: on ? 4 : 2)
            .scaleEffect(on ? 1.015 : 1)
            .animation(.easeInOut(duration: 0.2), value: on)
    }

    /// `.tile` from the design (58 pt rows in two-column grids). `red` is the allergy variant.
    func obTile(_ on: Bool, red: Bool = false) -> some View {
        let border: Color = on ? (red ? OB.red : OB.lemon) : .clear
        let fill: Color = on ? (red ? OB.redSoft : OB.selected) : .white
        let shadow: Color = on ? (red ? OB.red.opacity(0.18) : OB.lemon.opacity(0.25)) : OB.ink.opacity(0.05)
        return self
            .padding(.horizontal, 12)
            .frame(height: 58)
            .frame(maxWidth: .infinity)
            .background(fill, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(border, lineWidth: 2))
            .shadow(color: shadow, radius: on ? 7 : 5, x: 0, y: on ? 4 : 2)
            .scaleEffect(on ? 1.02 : 1)
            .animation(.easeInOut(duration: 0.2), value: on)
    }

    /// `bwin`: fade in while rising 12 pt.
    func obIn(delay: Double = 0, duration: Double = 0.35) -> some View {
        modifier(OBAppear(kind: .rise, delay: delay, duration: duration))
    }

    /// `bwpop`: scale from 0.6 with a small overshoot.
    func obPop(delay: Double = 0, duration: Double = 0.5) -> some View {
        modifier(OBAppear(kind: .pop, delay: delay, duration: duration))
    }
}

struct OBAppear: ViewModifier {
    enum Kind { case rise, pop, slide }
    let kind: Kind
    let delay: Double
    let duration: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : (kind == .rise ? 12 : kind == .slide ? -18 : 0))
            .scaleEffect(shown ? 1 : (kind == .pop ? 0.6 : kind == .slide ? 0.96 : 1))
            .onAppear {
                if reduceMotion { shown = true; return }
                let anim: Animation = kind == .pop
                    ? .spring(response: duration, dampingFraction: 0.62).delay(delay)
                    : .timingCurve(0.3, 0.7, 0.3, 1, duration: duration).delay(delay)
                withAnimation(anim) { shown = true }
            }
    }
}

/// Tiny Figtree text helper with exact size, weight, colour and tracking (CSS letter-spacing in em).
struct OBText: View {
    let text: String
    var size: CGFloat
    var weight: Int = 700
    var color: Color = OB.ink
    var tracking: CGFloat = 0
    var align: TextAlignment = .leading

    init(_ text: String, _ size: CGFloat, _ weight: Int = 700, color: Color = OB.ink, tracking: CGFloat = 0, align: TextAlignment = .leading) {
        self.text = text
        self.size = size
        self.weight = weight
        self.color = color
        self.tracking = tracking
        self.align = align
    }

    var body: some View {
        Text(text)
            .font(OB.font(size, weight))
            .tracking(size * tracking)
            .foregroundStyle(color)
            .multilineTextAlignment(align)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Bundled onboarding artwork (logos + Zesty base). Loaded from the app bundle by file name.
enum OBArt {
    static func image(_ name: String) -> Image {
        if let ui = UIImage(named: name) { return Image(uiImage: ui) }
        return Image(systemName: "questionmark.square.dashed")
    }
}
