import SwiftUI

/// Zesty's illustrated poses, with normalized eye rects (measured from the artwork) for blinking.
enum ZestPose {
    case wave, cheer, peek

    var imageName: String {
        switch self {
        case .wave: BWImage.mascotWave
        case .cheer: BWImage.mascotCheer
        case .peek: BWImage.mascotPeek
        }
    }

    var aspect: CGFloat {
        switch self {
        case .wave, .cheer: 846.0 / 785.0
        case .peek: 856.0 / 576.0
        }
    }

    var eyes: [CGRect] {
        switch self {
        case .wave:
            [CGRect(x: 0.4415, y: 0.4376, width: 0.065, height: 0.0803),
             CGRect(x: 0.6259, y: 0.4172, width: 0.065, height: 0.0803)]
        case .peek:
            [CGRect(x: 0.4918, y: 0.6771, width: 0.0701, height: 0.1146),
             CGRect(x: 0.7074, y: 0.6571, width: 0.0713, height: 0.1198)]
        case .cheer: []
        }
    }
}

/// Animated Zesty: breathing, gentle sway, natural blinks, an occasional happy hop,
/// and a quick "talking" bounce. Motion is disabled with Reduce Motion (blinks stay).
struct ZestView: View {
    var pose: ZestPose = .wave
    var size: CGFloat = 120
    var hopEvery: Double? = nil
    var talking: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe: Bool = false
    @State private var sway: Bool = false
    @State private var blink: Bool = false
    @State private var hop: Bool = false
    @State private var cheering: Bool = false
    @State private var talkPhase: Bool = false

    private var showsCheer: Bool { pose == .cheer || cheering }

    var body: some View {
        ZStack {
            art(pose == .peek ? .peek : .wave)
                .opacity(showsCheer ? 0 : 1)
            if pose != .peek {
                Image(ZestPose.cheer.imageName)
                    .resizable()
                    .scaledToFit()
                    .opacity(showsCheer ? 1 : 0)
            }
        }
        .frame(width: size, height: size / pose.aspect)
        .scaleEffect(x: breathe ? 1.018 : 0.992, y: breathe ? 0.988 : 1.012, anchor: .bottom)
        .scaleEffect(y: talkPhase ? 0.97 : 1, anchor: .bottom)
        .rotationEffect(.degrees(sway ? 2.2 : -2.2), anchor: .bottom)
        .offset(y: hop ? -size * 0.13 : 0)
        .accessibilityHidden(true)
        .onAppear(perform: startIdle)
        .task(id: "blink") { await blinkLoop() }
        .task(id: hopEvery) { await hopLoop() }
        .onChange(of: talking) { _, isTalking in updateTalking(isTalking) }
    }

    private func art(_ p: ZestPose) -> some View {
        Image(p.imageName)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geo in
                    ForEach(Array(p.eyes.enumerated()), id: \.offset) { _, eye in
                        eyelid(eye, in: geo.size)
                    }
                }
            }
    }

    private func eyelid(_ eye: CGRect, in canvas: CGSize) -> some View {
        let w = eye.width * canvas.width
        let h = eye.height * canvas.height
        return ZStack {
            Ellipse().fill(BW.zestSkin).frame(width: w * 1.6, height: h * 1.45)
            Capsule().fill(Color(hex: 0x1E1A12)).frame(width: w * 1.05, height: max(2, h * 0.16)).offset(y: h * 0.12)
        }
        .scaleEffect(y: blink ? 1 : 0.05, anchor: .top)
        .opacity(blink ? 1 : 0)
        .position(x: eye.midXNormalized * canvas.width, y: eye.midYNormalized * canvas.height)
    }

    private func startIdle() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) { breathe = true }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { sway = true }
    }

    private func blinkLoop() async {
        guard !pose.eyes.isEmpty else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.2...4.4)))
            if Task.isCancelled { return }
            await singleBlink()
            if Bool.random() && Double.random(in: 0...1) < 0.25 {
                try? await Task.sleep(for: .milliseconds(140))
                await singleBlink()
            }
        }
    }

    private func singleBlink() async {
        withAnimation(.easeIn(duration: 0.06)) { blink = true }
        try? await Task.sleep(for: .milliseconds(110))
        withAnimation(.easeOut(duration: 0.09)) { blink = false }
    }

    private func hopLoop() async {
        guard let hopEvery, !reduceMotion else { return }
        try? await Task.sleep(for: .seconds(1.2))
        while !Task.isCancelled {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) { hop = true; cheering = true }
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) { hop = false }
            try? await Task.sleep(for: .milliseconds(1300))
            withAnimation(.easeInOut(duration: 0.25)) { cheering = false }
            try? await Task.sleep(for: .seconds(hopEvery))
        }
    }

    private func updateTalking(_ isTalking: Bool) {
        guard !reduceMotion else { return }
        if isTalking {
            withAnimation(.easeInOut(duration: 0.16).repeatForever(autoreverses: true)) { talkPhase = true }
        } else {
            withAnimation(.easeOut(duration: 0.15)) { talkPhase = false }
        }
    }
}

private extension CGRect {
    /// Eye rects store their center in origin for readability.
    var midXNormalized: CGFloat { origin.x }
    var midYNormalized: CGFloat { origin.y }
}

/// Speech bubble that "types" Zesty's line and reports when Zesty is talking.
struct ZestBubble: View {
    let text: String
    var tail: HorizontalEdge = .leading
    @Binding var isTalking: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible: Int = 0
    @State private var shown: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text).opacity(0)
            Text(String(text.prefix(visible)))
        }
        .font(.bw(.subheadline, weight: .semibold))
        .foregroundStyle(BW.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(BW.card, in: .rect(cornerRadius: 18))
        .overlay(alignment: tail == .leading ? .bottomLeading : .bottomTrailing) {
            BubbleTail()
                .fill(BW.card)
                .frame(width: 14, height: 10)
                .scaleEffect(x: tail == .leading ? 1 : -1)
                .offset(x: tail == .leading ? -5 : 5, y: -6)
        }
        .shadow(color: BW.ink.opacity(0.08), radius: 10, x: 0, y: 4)
        .scaleEffect(shown ? 1 : 0.6, anchor: tail == .leading ? .bottomLeading : .bottomTrailing)
        .opacity(shown ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
        .task(id: text) { await type() }
    }

    private func type() async {
        visible = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { shown = true }
        if reduceMotion {
            visible = text.count
            return
        }
        try? await Task.sleep(for: .milliseconds(180))
        isTalking = true
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        var count = 0
        for word in words {
            if Task.isCancelled { break }
            count = min(text.count, count + word.count + 1)
            visible = count
            try? await Task.sleep(for: .milliseconds(85))
        }
        visible = text.count
        isTalking = false
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX * 0.9, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Zesty with a typed speech bubble; Zesty bounces while "speaking".
struct ZestGuide: View {
    let text: String
    var pose: ZestPose = .wave
    var size: CGFloat = 64
    @State private var talking: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZestView(pose: pose, size: size, talking: talking)
            ZestBubble(text: text, isTalking: $talking)
                .padding(.bottom, size * 0.35)
            Spacer(minLength: 0)
        }
    }
}

/// Soft radial sun rays behind Zesty. Rotates very slowly unless Reduce Motion is on.
struct SunburstView: View {
    var rays: Int = 18
    var color: Color = Color(hex: 0xF6E39A)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = max(size.width, size.height)
            let step = Double.pi * 2 / Double(rays)
            for i in 0..<rays {
                let a = Double(i) * step
                var p = Path()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                p.addLine(to: CGPoint(x: c.x + cos(a + step * 0.5) * r, y: c.y + sin(a + step * 0.5) * r))
                p.closeSubpath()
                ctx.fill(p, with: .color(color))
            }
        }
        .mask(RadialGradient(colors: [.white, .white.opacity(0.6), .clear], center: .center, startRadius: 10, endRadius: 250))
        .rotationEffect(.degrees(spin ? 360 : 0))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}

/// A few softly floating dots, like the reference hero.
struct FloatingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up: Bool = false

    private let dots: [(x: CGFloat, y: CGFloat, size: CGFloat, color: Color, delay: Double)] = [
        (0.2, 0.3, 12, Color(hex: 0xF4E18C), 0), (0.84, 0.62, 10, Color(hex: 0xE6A463), 0.6),
        (0.12, 0.72, 7, Color(hex: 0xE6A463), 1.1), (0.78, 0.2, 8, Color(hex: 0xF4E18C), 0.3),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(dots.enumerated()), id: \.offset) { i, d in
                Circle()
                    .fill(d.color)
                    .frame(width: d.size, height: d.size)
                    .position(x: geo.size.width * d.x, y: geo.size.height * d.y)
                    .offset(y: up ? (i.isMultiple(of: 2) ? -8 : 6) : 0)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 2.4 + Double(i) * 0.3).repeatForever(autoreverses: true).delay(d.delay), value: up)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { up = true }
    }
}

/// Primary CTA with a soft glossy highlight that sweeps across occasionally.
/// The highlight sits under the label so the text stays fully readable.
struct ShineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ShineButtonBody(configuration: configuration)
    }
}

private struct ShineButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @State private var phase: CGFloat = -0.3

    var body: some View {
        configuration.label
            .font(.bw(.title3, weight: .heavy))
            .foregroundStyle(BW.ink)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background {
                ZStack {
                    Capsule().fill(LinearGradient(colors: [BW.lemonBright, BW.lemon], startPoint: .top, endPoint: .bottom))
                    GeometryReader { geo in
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.75), .white.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.22, height: geo.size.height * 2.2)
                            .rotationEffect(.degrees(20))
                            .position(x: phase * geo.size.width, y: geo.size.height / 2)
                    }
                    .opacity(reduceMotion ? 0 : 1)
                }
                .clipShape(.capsule)
            }
            .shadow(color: BW.lemon.opacity(0.45), radius: 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .task { await shineLoop() }
    }

    private func shineLoop() async {
        guard !reduceMotion else { return }
        try? await Task.sleep(for: .seconds(1.0))
        while !Task.isCancelled {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { phase = -0.3 }
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.easeInOut(duration: 1.25)) { phase = 1.3 }
            try? await Task.sleep(for: .seconds(4.2))
        }
    }
}

/// Small one-shot confetti burst for celebratory moments. Skipped with Reduce Motion.
struct ConfettiView: View {
    var count: Int = 44
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date = .now
    @State private var pieces: [ConfettiPiece] = []
    @State private var finished: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: finished || reduceMotion)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let x = size.width * p.x + p.vx * t
                    let y = size.height * p.y + p.vy * t + 560 * t * t
                    var c = ctx
                    c.opacity = max(0, 1 - max(0, t - 1.5))
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .degrees(p.angle + p.spin * t))
                    let h = p.h * max(0.2, abs(cos(t * p.flip)))
                    c.fill(Path(roundedRect: CGRect(x: -p.w / 2, y: -h / 2, width: p.w, height: h), cornerRadius: 1.5),
                           with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            start = .now
            let palette: [Color] = [BW.lemon, BW.leaf, BW.apricot, Color(hex: 0xF4E18C), BW.ink.opacity(0.85)]
            pieces = (0..<count).map { _ in
                ConfettiPiece(x: .random(in: 0.35...0.65), y: .random(in: 0.22...0.32),
                              vx: .random(in: -260...260), vy: .random(in: -640...(-260)),
                              w: .random(in: 6...10), h: .random(in: 10...16),
                              angle: .random(in: 0...360), spin: .random(in: -320...320),
                              flip: .random(in: 3...9), color: palette.randomElement() ?? BW.lemon)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(3))
            finished = true
        }
    }
}

private struct ConfettiPiece {
    let x: CGFloat
    let y: CGFloat
    let vx: CGFloat
    let vy: CGFloat
    let w: CGFloat
    let h: CGFloat
    let angle: Double
    let spin: Double
    let flip: Double
    let color: Color
}

/// Page title in the same Figtree ExtraBold and tracking as the Lemora wordmark.
struct LemoraPageTitle: View {
    let title: LocalizedStringKey
    var size: CGFloat = 40

    var body: some View {
        Text(title)
            .font(.custom(LemoraFont.name(for: .heavy), size: size))
            .tracking(-size * 0.025)
            .foregroundStyle(BW.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// The "lemora" wordmark set in Figtree ExtraBold, lowercase, tight tracking.
struct LemoraWordmark: View {
    var size: CGFloat = 32
    var color: Color = BW.ink

    var body: some View {
        Text(verbatim: "lemora")
            .font(.custom(LemoraFont.name(for: .heavy), size: size))
            .tracking(-size * 0.025)
            .foregroundStyle(color)
            .accessibilityLabel(Text(verbatim: "Lemora"))
    }
}

extension EnvironmentValues {
    /// True inside onboarding, where each question is introduced by Zesty.
    @Entry var showsZestGuide: Bool = false
}
