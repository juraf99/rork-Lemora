import SwiftUI

struct DiscoverView: View {
    @Environment(AppStore.self) private var store
    @State private var path: NavigationPath = NavigationPath()
    @State private var drag: CGSize = .zero
    @State private var flyOut: SwipeDirection? = nil
    @State private var showPaywall: Bool = false
    @State private var showWhy: Bool = false
    @State private var likeTrigger: Int = 0
    @State private var passTrigger: Int = 0

    private var queue: [ScoredRecipe] { store.discoverQueue }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                if !store.canSwipe {
                    limitReached
                } else if let top = queue.first {
                    cardArea(top)
                    actions(top)
                } else {
                    EmptyStateView(mascot: BWImage.mascotCheer,
                                   title: String(localized: "You've seen every meal for now"),
                                   message: String(localized: "New recipes arrive as we grow the library. Check your saved meals or this week's deals."),
                                   actionTitle: String(localized: "Start over"),
                                   action: { store.restartDiscovery() })
                        .frame(maxHeight: .infinity)
                }
            }
            .background(BW.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .bitewiseDestinations()
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: .upgrade) { showPaywall = false }
            }
            .onAppear { store.track("discover_opened") }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(BW.ink)
                Text(subtitle)
                    .font(.bw(.subheadline, weight: .regular))
                    .foregroundStyle(BW.inkSecondary)
            }
            Spacer(minLength: 8)
            Button { path.append(Route.streaks) } label: {
                StreakPill(days: store.wiseStreakDays)
            }
            .buttonStyle(BWPressableStyle())
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return String(localized: "Good morning!")
        case 12..<18: return String(localized: "Good afternoon!")
        default: return String(localized: "Good evening!")
        }
    }

    private var subtitle: String {
        if store.isCalibrating {
            let left = store.config.calibrationSwipes - store.calibrationDone
            return String(localized: "Tasting round: \(left) more to learn your taste")
        }
        if let left = store.swipesRemaining {
            return String(localized: "\(left) free swipes left today")
        }
        return String(localized: "Find something delicious today.")
    }

    // MARK: Card

    private func cardArea(_ top: ScoredRecipe) -> some View {
        ZStack {
            if queue.count > 1 {
                RecipeSwipeCard(item: queue[1], showWhy: .constant(false))
                    .scaleEffect(0.94)
                    .offset(y: 14)
                    .opacity(0.7)
                    .allowsHitTesting(false)
            }
            RecipeSwipeCard(item: top, showWhy: $showWhy)
                .overlay(alignment: .topLeading) { stamp }
                .offset(x: drag.width, y: drag.height * 0.3)
                .rotationEffect(.degrees(Double(drag.width) / 22))
                .gesture(
                    DragGesture()
                        .onChanged { drag = $0.translation }
                        .onEnded { value in
                            if value.translation.width > 110 { commit(.like, top) }
                            else if value.translation.width < -110 { commit(.pass, top) }
                            else { withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = .zero } }
                        }
                )
                .onTapGesture { path.append(Route.recipe(top.id)) }
                .overlay(alignment: .topTrailing) {
                    MascotView(name: BWImage.mascotPeek, size: 84)
                        .offset(x: -18, y: -50)
                        .allowsHitTesting(false)
                        .opacity(abs(drag.width) > 20 ? 0 : 1)
                        .animation(.easeOut(duration: 0.15), value: drag.width)
                }
                .accessibilityElement(children: .combine)
                .accessibilityHint(Text("Double tap for details. Use the Like and Pass buttons below."))
                .accessibilityAction(named: Text("Like")) { commit(.like, top) }
                .accessibilityAction(named: Text("Pass")) { commit(.pass, top) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 52)
        .frame(maxHeight: .infinity)
        .sheet(isPresented: $showWhy) {
            WhyThisSheet(item: top)
        }
    }

    @ViewBuilder
    private var stamp: some View {
        let progress = min(1, abs(drag.width) / 110)
        if drag.width > 10 {
            Text("YUM").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(BW.ink)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(BW.lemon, in: .rect(cornerRadius: 12))
                .rotationEffect(.degrees(-12)).padding(24).opacity(progress)
        } else if drag.width < -10 {
            Text("NOPE").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(BW.ink)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(.white, in: .rect(cornerRadius: 12))
                .rotationEffect(.degrees(12)).padding(24).opacity(progress)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func actions(_ top: ScoredRecipe) -> some View {
        HStack(spacing: 36) {
            Button { commit(.pass, top) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(BW.inkSecondary)
                    .frame(width: 84, height: 84)
                    .background(BW.card, in: .circle)
                    .shadow(color: BW.ink.opacity(0.08), radius: 12, y: 6)
            }
            .buttonStyle(BWPressableStyle())
            .accessibilityLabel("Pass")
            .sensoryFeedback(.impact(weight: .light), trigger: passTrigger)

            Button { commit(.like, top) } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(BW.ink)
                    .frame(width: 96, height: 96)
                    .background(BW.lemon, in: .circle)
                    .shadow(color: BW.amber.opacity(0.3), radius: 14, y: 6)
            }
            .buttonStyle(BWPressableStyle())
            .accessibilityLabel("Like")
            .sensoryFeedback(.success, trigger: likeTrigger)
        }
        .padding(.vertical, 18)
    }

    private func commit(_ direction: SwipeDirection, _ item: ScoredRecipe) {
        guard flyOut == nil else { return }
        flyOut = direction
        if direction == .like { likeTrigger += 1 } else { passTrigger += 1 }
        withAnimation(.easeIn(duration: 0.22)) {
            drag = CGSize(width: direction == .like ? 600 : -600, height: 40)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            store.swipe(item, direction)
            drag = .zero
            flyOut = nil
        }
    }

    // MARK: Limit

    private var limitReached: some View {
        VStack(spacing: 16) {
            Spacer()
            MascotView(name: BWImage.mascotCheer, size: 130, bob: true)
            Text("You've discovered today's meals.")
                .font(.bw(.title2)).foregroundStyle(BW.ink).multilineTextAlignment(.center)
            Text("Next free swipes: tomorrow")
                .font(.bw(.subheadline, weight: .medium)).foregroundStyle(BW.inkSecondary)
            Button("Unlock Unlimited Swipes") { showPaywall = true }
                .buttonStyle(BWPrimaryButtonStyle())
                .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

/// The hero swipe card: food first, stats overlaid, match + reason below the title.
struct RecipeSwipeCard: View {
    let item: ScoredRecipe
    @Binding var showWhy: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                FoodImage(name: item.recipe.imageName, height: geo.size.height, radius: BW.heroRadius)
                LinearGradient(colors: [.clear, .clear, .black.opacity(0.55), .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                    .clipShape(.rect(cornerRadius: BW.heroRadius))
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 12) {
                    Text(item.recipe.title)
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: 12) {
                        stat("fork.knife", "\(item.recipe.nutrition.protein)g protein")
                        divider
                        stat("tag", "\(Money.format(item.price.perServing)) / serving")
                        divider
                        stat("clock", "\(item.recipe.totalMinutes) min")
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                    HStack(spacing: 8) {
                        MatchBadge(percent: item.matchPercent)
                        if let reason = item.primaryReason {
                            Button { showWhy = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: reason.code == .currentDeal ? "tag" : "sparkles")
                                    Text(reason.text).lineLimit(1)
                                    Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                                }
                                .font(.bw(.subheadline, weight: .medium))
                                .foregroundStyle(BW.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.white.opacity(0.94), in: .capsule)
                            }
                            .accessibilityLabel(Text("Why this? \(reason.text)"))
                        }
                    }
                }
                .padding(20)
            }
        }
        .shadow(color: BW.ink.opacity(0.14), radius: 20, y: 10)
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.4)).frame(width: 1, height: 16)
    }

    private func stat(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
            Text(text).monospacedDigit()
        }
        .font(.bw(.subheadline, weight: .medium))
        .foregroundStyle(.white)
    }
}

struct WhyThisSheet: View {
    let item: ScoredRecipe

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                MascotView(name: BWImage.mascotWave, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Why this?").font(.bw(.title2)).foregroundStyle(BW.ink)
                    Text(item.recipe.title).font(.bw(.subheadline, weight: .medium)).foregroundStyle(BW.inkSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(item.reasons, id: \.self) { reason in
                    HStack(spacing: 12) {
                        Image(systemName: reason.code == .currentDeal ? "tag.fill" : "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(reason.code == .currentDeal ? .white : BW.ink)
                            .frame(width: 30, height: 30)
                            .background(reason.code == .currentDeal ? BW.leaf : BW.lemon, in: .circle)
                        Text(reason.text).font(.bw(.body, weight: .medium)).foregroundStyle(BW.ink)
                    }
                }
            }
            if item.price.usesSampleData { SamplePricesNote() }
            Spacer(minLength: 0)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(BW.canvas)
    }
}
