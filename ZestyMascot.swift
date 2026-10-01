import SwiftUI

/// Where Zesty is looking (-1...1 on each axis). One shared wandering gaze, like the design.
@Observable
final class ZestyGaze {
    static let shared = ZestyGaze()
    var x: CGFloat = 0
    var y: CGFloat = 0
    private var task: Task<Void, Never>?

    func start() {
        guard task == nil else { return }
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1800))
                guard let self else { return }
                withAnimation(.timingCurve(0.3, 0.7, 0.3, 1, duration: 0.22)) {
                    if Double.random(in: 0...1) < 0.35 {
                        self.x = 0; self.y = 0
                    } else {
                        self.x = CGFloat.random(in: -0.8...0.8)
                        self.y = CGFloat.random(in: -0.5...0.5)
                    }
                }
            }
        }
    }
}

/// Zesty, the Lemora lemon, with the moods and motions of the onboarding design
/// (bob, breathe, blink, talk, think, jump, celebrate, love, sad, dizzy, tap-to-poke).
struct ZestyMascot: View {
    enum Mood: String {
        case idle, talking, thinking, happy, celebrating, wave, idea, curious, cart, love, sad, dizzy, impatient, cheer
    }

    let mood: Mood
    let size: CGFloat
    var seedKey: String = ""

    @State private var start = Date()
    @State private var pokeUntil: Date = .distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var gaze: ZestyGaze { ZestyGaze.shared }

    private var height: CGFloat { (size * 1.016).rounded() }
    private var seed: Double { Double((seedKey.isEmpty ? mood.rawValue : seedKey).count % 5) }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(start)
            let poked = tl.date < pokeUntil
            let m: Mood = poked ? .cheer : mood
            content(mood: m, t: poked ? tl.date.timeIntervalSince(pokeUntil.addingTimeInterval(-0.9)) : t, blinkT: t, poked: poked)
        }
        .frame(width: size, height: height)
        .contentShape(Rectangle())
        .onTapGesture {
            pokeUntil = Date().addingTimeInterval(0.9)
        }
        .onAppear { ZestyGaze.shared.start() }
        .accessibilityHidden(true)
    }

    // MARK: Composition

    @ViewBuilder
    private func content(mood m: Mood, t: Double, blinkT: Double, poked: Bool) -> some View {
        let outer = outerTransform(m, t)
        let bobbing = ![.thinking, .celebrating, .curious, .dizzy, .sad, .impatient, .cheer].contains(m)
        let bobP = bobbing ? cycle(t - 0.6, 2.8) : 0
        let bob = ease(bobP)
        let breathe = ease(cycle(t, 3.2))

        ZStack {
            // Soft shadow under Zesty.
            Ellipse()
                .fill(OB.ink.opacity(0.14))
                .frame(width: size * 0.56, height: size * 0.06)
                .blur(radius: 2)
                .scaleEffect(bobbing ? 1 - 0.18 * bob : 1)
                .opacity(bobbing ? 1 - 0.4 * bob : 1)
                .offset(y: height / 2 + size * 0.0)

            figure(mood: m, blinkT: blinkT)
                .scaleEffect(x: 1 + 0.022 * breathe, y: 1 - 0.025 * breathe, anchor: .bottom)
                .offset(y: -6 * bob)
                .rotationEffect(.degrees(bobbing ? Double(-2 + 4 * bob) : 0), anchor: .center)

            if m == .thinking { thinkingDots(t) }
            if m == .happy { twinkles(t) }
            if poked { burst(t) }
        }
        .scaleEffect(x: outer.sx, y: outer.sy, anchor: .bottom)
        .rotationEffect(.degrees(Double(outer.rot)), anchor: .bottom)
        .offset(x: outer.x, y: outer.y)
    }

    @ViewBuilder
    private func figure(mood m: Mood, blinkT: Double) -> some View {
        if let pose = poseImage(m) {
            (pose.hasPrefix("zesty_") ? OBArt.image(pose) : Image(pose))
                .resizable()
                .scaledToFit()
                .frame(width: size, height: height)
                .scaleEffect(1.12)
        } else {
            ZStack(alignment: .topLeading) {
                OBArt.image("zesty_base")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: height)
                face(joy: m == .happy || m == .celebrating || m == .wave, thinking: m == .thinking, blinkT: blinkT)
            }
            .frame(width: size, height: height)
        }
    }

    private func poseImage(_ m: Mood) -> String? {
        switch m {
        case .idea: "zesty_idea"
        case .curious: "zesty_curious"
        case .cart: "zesty_cart"
        case .love: "zesty_love"
        case .sad: "zesty_sad"
        case .dizzy: "zesty_dizzy"
        case .impatient: "zesty_impatient"
        case .celebrating, .cheer: "lemon_mascot_cheering"
        default: nil
        }
    }

    // MARK: Face (eye patches + animated eyes over the base art)

    private func face(joy: Bool, thinking: Bool, blinkT: Double) -> some View {
        let w = size, h = height
        return ZStack(alignment: .topLeading) {
            patch(0.455, 0.378, w, h)
            patch(0.65, 0.373, w, h)
            eye(0.469, 0.391, w, h, joy: joy, thinking: thinking, blinkT: blinkT)
            eye(0.664, 0.386, w, h, joy: joy, thinking: thinking, blinkT: blinkT)
            if joy {
                blush(0.405, 0.48, w, h)
                blush(0.75, 0.47, w, h)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    private func patch(_ l: CGFloat, _ tp: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View {
        Ellipse()
            .fill(RadialGradient(stops: [.init(color: Color(hex: 0xE2CC47), location: 0),
                                         .init(color: Color(hex: 0xE2CC47), location: 0.72),
                                         .init(color: Color(hex: 0xE2CC47, opacity: 0), location: 1)],
                                 center: .center, startRadius: 0, endRadius: w * 0.045))
            .frame(width: w * 0.09, height: h * 0.10)
            .offset(x: l * w, y: tp * h)
    }

    private func blush(_ l: CGFloat, _ tp: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color(red: 240 / 255, green: 110 / 255, blue: 80 / 255, opacity: 0.45),
                                          Color(red: 240 / 255, green: 110 / 255, blue: 80 / 255, opacity: 0)],
                                 center: .center, startRadius: 0, endRadius: w * 0.04))
            .frame(width: w * 0.08, height: h * 0.045)
            .offset(x: l * w, y: tp * h)
    }

    private func eye(_ l: CGFloat, _ tp: CGFloat, _ w: CGFloat, _ h: CGFloat, joy: Bool, thinking: Bool, blinkT: Double) -> some View {
        let ew = w * 0.062, eh = h * 0.0745
        let dx = thinking ? size * 0.02 : gaze.x * size * 0.028
        let dy = thinking ? -size * 0.022 : gaze.y * size * 0.022
        let period = 3.6 + seed * 0.7
        let p = cycle(blinkT - seed * 0.4, period)
        let blinkValue: Double = (p > 0.93 && p < 1) ? (p < 0.96 ? 1 - (p - 0.93) / 0.03 * 0.92 : 0.08 + (p - 0.96) / 0.04 * 0.92) : 1
        let blink = CGFloat(blinkValue)
        return Group {
            if joy {
                JoyArc()
                    .stroke(Color(hex: 0x2B2D29), style: StrokeStyle(lineWidth: max(2, size * 0.022), lineCap: .round))
                    .frame(width: ew * 1.2, height: eh * 0.55)
                    .offset(y: eh * 0.25)
            } else {
                ZStack(alignment: .topTrailing) {
                    Ellipse().fill(Color(hex: 0x2B2D29))
                    Ellipse().fill(.white.opacity(0.9))
                        .frame(width: ew * 0.32, height: eh * 0.28)
                        .offset(x: -ew * 0.18, y: eh * 0.16)
                }
                .frame(width: ew, height: eh)
                .scaleEffect(y: blink)
            }
        }
        .frame(width: ew, height: eh)
        .offset(x: l * w + dx, y: tp * h + dy)
    }

    // MARK: Extras

    private func thinkingDots(_ t: Double) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                let p = ease(cycle(t - Double(i) * 0.18, 1))
                Circle().fill(OB.ink)
                    .frame(width: 5, height: 5)
                    .opacity(0.25 + 0.75 * p)
                    .offset(y: -3 * p)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.white, in: .capsule)
        .shadow(color: OB.ink.opacity(0.12), radius: 5, x: 0, y: 3)
        .position(x: size * 1.08, y: 8)
    }

    private func twinkles(_ t: Double) -> some View {
        let spots: [(CGFloat, CGFloat, Color, Double)] = [(-0.1, 0.1, OB.lemon, 0), (1.02, 0.05, OB.leaf, 0.4), (0.95, 0.7, OB.orange, 0.8)]
        return ZStack {
            ForEach(0..<spots.count, id: \.self) { i in
                let s = spots[i]
                let p = ease(cycle(t - s.3, 1.6))
                Circle().fill(s.2)
                    .frame(width: 8, height: 8)
                    .scaleEffect(0.4 + 0.6 * p)
                    .opacity(p)
                    .position(x: s.0 * size + 4, y: s.1 * size + 4)
            }
        }
        .frame(width: size, height: height)
    }

    private func burst(_ t: Double) -> some View {
        let k = min(1, max(0, t / 0.7))
        let e = 1 - pow(1 - k, 2)
        return ZStack {
            ForEach(0..<6, id: \.self) { i in
                let a = Double(i) / 6 * .pi * 2
                Circle().fill([OB.lemon, OB.leaf, OB.orange][i % 3])
                    .frame(width: 7, height: 7)
                    .scaleEffect(0.4 + 0.6 * e)
                    .opacity(1 - e)
                    .offset(x: cos(a) * size * 0.7 * e, y: sin(a) * size * 0.6 * e)
                    .position(x: size / 2, y: height * 0.4)
            }
        }
        .frame(width: size, height: height)
        .allowsHitTesting(false)
    }

    // MARK: Motion curves (CSS keyframes from the design)

    private struct T { var x: CGFloat = 0; var y: CGFloat = 0; var sx: CGFloat = 1; var sy: CGFloat = 1; var rot: CGFloat = 0 }

    private func outerTransform(_ m: Mood, _ t: Double) -> T {
        guard !reduceMotion else { return T() }
        switch m {
        case .talking:
            guard t < 0.42 * 4 else { return T() }
            let s = ease(cycle(t, 0.42))
            return T(y: -3 * s, sx: 1 + 0.04 * s, sy: 1 - 0.04 * s, rot: -3 * s)
        case .thinking, .curious, .dizzy:
            let s = ease(cycle(t, m == .thinking ? 2.2 : m == .curious ? 2.6 : 1.1))
            return T(y: -3 * s, rot: -6 + 12 * s)
        case .happy, .idea:
            return jump(t)
        case .celebrating:
            return celebrate(cycle(t, 1.2))
        case .cheer:
            return t < 1.2 ? celebrate(t / 1.2) : T()
        case .wave:
            let p = cycle(t, 1.8)
            let r = keyframes(p, [(0, 0), (0.15, -12), (0.3, 10), (0.45, -8), (0.6, 6), (0.75, 0), (1, 0)])
            return T(rot: r)
        case .cart:
            let p = cycle(t, 1.4)
            return T(x: keyframes(p, [(0, 0), (0.25, -5), (0.75, 5), (1, 0)]), rot: keyframes(p, [(0, 0), (0.25, -3), (0.75, 3), (1, 0)]))
        case .love:
            let s = ease(cycle(t, 1.2))
            return T(sx: 1 + 0.06 * s, sy: 1 + 0.06 * s)
        case .sad:
            let s = ease(cycle(t, 2.4))
            return T(y: 3 * s, sx: 1 + 0.02 * s, sy: 1 - 0.03 * s)
        case .impatient:
            guard t < 2 else { return T() }
            let p = cycle(t, 0.5)
            return T(x: keyframes(p, [(0, 0), (0.2, -3), (0.4, 3), (0.6, -3), (0.8, 3), (1, 0)]),
                     rot: keyframes(p, [(0, 0), (0.2, -2), (0.4, 2), (0.6, -2), (0.8, 2), (1, 0)]))
        case .idle:
            return T()
        }
    }

    private func jump(_ t: Double) -> T {
        guard t < 0.65 else { return T() }
        let p = t / 0.65
        return T(y: keyframes(p, [(0, 0), (0.3, -16), (0.55, 0), (1, 0)]),
                 sx: keyframes(p, [(0, 1), (0.3, 0.94), (0.55, 1.1), (0.75, 0.98), (1, 1)]),
                 sy: keyframes(p, [(0, 1), (0.3, 1.08), (0.55, 0.9), (0.75, 1.02), (1, 1)]))
    }

    private func celebrate(_ p: Double) -> T {
        T(y: keyframes(p, [(0, 0), (0.25, -22), (0.5, 0), (0.75, -14), (1, 0)]),
          sx: keyframes(p, [(0, 1), (0.25, 1), (0.5, 1.08), (0.75, 1), (1, 1)]),
          sy: keyframes(p, [(0, 1), (0.25, 1), (0.5, 0.92), (0.75, 1), (1, 1)]),
          rot: keyframes(p, [(0, 0), (0.25, -10), (0.5, 0), (0.75, 10), (1, 0)]))
    }

    /// 0...1 progress within a repeating cycle (0 before the first cycle starts).
    private func cycle(_ t: Double, _ period: Double) -> Double {
        guard t > 0 else { return 0 }
        return t.truncatingRemainder(dividingBy: period) / period
    }

    /// 0 → 1 → 0 ease-in-out bump over a cycle.
    private func ease(_ p: Double) -> CGFloat {
        CGFloat((1 - cos(2 * .pi * p)) / 2)
    }

    private func keyframes(_ p: Double, _ frames: [(Double, Double)]) -> CGFloat {
        guard let first = frames.first else { return 0 }
        if p <= first.0 { return CGFloat(first.1) }
        for i in 1..<frames.count where p <= frames[i].0 {
            let a = frames[i - 1], b = frames[i]
            let k = (p - a.0) / max(0.0001, b.0 - a.0)
            let e = k < 0.5 ? 2 * k * k : 1 - pow(-2 * k + 2, 2) / 2
            return CGFloat(a.1 + (b.1 - a.1) * e)
        }
        return CGFloat(frames.last?.1 ?? 0)
    }
}

/// Upper half of an ellipse, used for Zesty's happy (^ ^) eyes.
private struct JoyArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width / 2,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        return p.applying(CGAffineTransform(translationX: 0, y: 0))
    }
}
