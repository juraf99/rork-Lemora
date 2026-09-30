import SwiftUI
import Combine

/// Landing screen. The looping product story is rendered natively (swipe -> deal -> price per serving
/// -> Worth It -> goals) as a placeholder until the produced 10-second landing video is available.
struct LandingView: View {
    let onStart: () -> Void
    let onSignIn: () -> Void

    @State private var language: String = Locale.current.language.languageCode?.identifier == "fr" ? "FR" : "EN"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    MascotView(name: BWImage.mascotPeek, size: 34)
                    Text("Lemora").font(.bw(.title3, weight: .heavy)).foregroundStyle(BW.ink)
                }
                Spacer()
                Picker("Language", selection: $language) {
                    Text("EN").tag("EN")
                    Text("FR").tag("FR")
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            LandingStoryView()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxHeight: .infinity)

            VStack(spacing: 14) {
                Text("Eat what you love.\nPay less.")
                    .font(.bw(.largeTitle, weight: .heavy))
                    .foregroundStyle(BW.ink)
                    .multilineTextAlignment(.center)

                Button("Get Started", action: onStart)
                    .buttonStyle(BWPrimaryButtonStyle())

                HStack(spacing: 4) {
                    Text("Already have an account?").foregroundStyle(BW.inkSecondary)
                    Button("Sign In", action: onSignIn).fontWeight(.bold).foregroundStyle(BW.ink)
                }
                .font(.bw(.subheadline, weight: .medium))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(BW.canvas)
        .onAppear { }
    }
}

/// Auto-advancing scenes that explain the product without sound in the first seconds.
struct LandingStoryView: View {
    @State private var scene: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: BW.heroRadius).fill(BW.beigeSoft)
            Group {
                switch scene {
                case 0: swipeScene
                case 1: dealScene
                case 2: worthItScene
                default: goalsScene
                }
            }
            .id(scene)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .padding(18)
        }
        .clipShape(.rect(cornerRadius: BW.heroRadius))
        .onReceive(timer) { _ in
            withAnimation(reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.85)) {
                scene = (scene + 1) % 4
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Swipe meals you love. Lemora finds grocery deals and shows the price per serving."))
    }

    private var swipeScene: some View {
        ZStack(alignment: .bottomLeading) {
            FoodImage(name: "chicken_burrito_bowl", radius: 24)
            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                .clipShape(.rect(cornerRadius: 24))
            VStack(alignment: .leading, spacing: 8) {
                Text("Crispy Chicken Burrito Bowl").font(.bw(.title3)).foregroundStyle(.white)
                HStack {
                    MatchBadge(percent: 94, compact: true)
                    Spacer()
                    Image(systemName: "heart.fill").font(.title2).foregroundStyle(BW.lemon)
                }
            }
            .padding(16)
        }
        .rotationEffect(.degrees(4))
    }

    private var dealScene: some View {
        VStack(spacing: 16) {
            FoodImage(name: "chicken_breasts_cutting_board", height: 170, radius: 22)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Chicken").font(.bw(.title3)).foregroundStyle(BW.ink)
                Spacer()
                Text("$15.99").font(.bw(.title3, weight: .semibold)).strikethrough().foregroundStyle(BW.inkSecondary)
                Image(systemName: "arrow.right").foregroundStyle(BW.inkSecondary)
                Text("$10.99").font(.bw(.title2, weight: .heavy)).foregroundStyle(BW.leafDeep)
            }
            Text("$3.82 / serving")
                .font(.bw(size: 34, weight: .heavy)).monospacedDigit()
                .foregroundStyle(BW.ink)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(BW.lemon, in: .capsule)
        }
    }

    private var worthItScene: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Worth It This Week").font(.bw(.title2)).foregroundStyle(BW.ink)
            HStack(spacing: 10) {
                ForEach(["teriyaki_chicken_rice_bowl", "close_up_food", "carne_asada_tacos"], id: \.self) { name in
                    FoodImage(name: name, height: 200, radius: 18)
                }
            }
            HStack {
                SoftChip(text: "Save $11 this week", symbol: "leaf.fill", fill: BW.leafSoft, foreground: BW.leafDeep)
                Spacer()
            }
        }
    }

    private var goalsScene: some View {
        VStack(spacing: 18) {
            MascotView(name: BWImage.mascotCheer, size: 120)
            let chips = ["Build Muscle", "Eat Healthier", "Save Money", "High Protein", "Vegetarian"]
            VStack(spacing: 10) {
                HStack(spacing: 8) { ForEach(chips.prefix(2), id: \.self) { SoftChip(text: $0, fill: .white) } }
                HStack(spacing: 8) { ForEach(chips.dropFirst(2).prefix(2), id: \.self) { SoftChip(text: $0, fill: BW.lemon) } }
                SoftChip(text: chips[4], fill: .white)
            }
            Text("Meals for your goals, near your stores.")
                .font(.bw(.subheadline, weight: .medium)).foregroundStyle(BW.inkSecondary)
        }
    }
}
