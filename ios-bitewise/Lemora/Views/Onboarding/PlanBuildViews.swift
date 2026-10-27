import SwiftUI

/// "Build My Plan": a personalized loading sequence where each line reflects the user's answers.
struct BuildingPlanView: View {
    let profile: UserProfile
    let preview: PlanPreview
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var completed: Int = 0
    @State private var percent: Double = 0

    private var tasks: [String] {
        var lines: [String] = [String(localized: "Tuning meals for your goal: \(profile.goal.title.lowercased())")]
        let allergies = profile.allergyNames.sorted()
        if allergies.isEmpty {
            lines.append(String(localized: "Checking every ingredient against your diet"))
        } else {
            lines.append(String(localized: "Blocking \(AppFormat.list(allergies.map { lemoraLocalized($0) })) in every recipe"))
        }
        lines.append(String(localized: "Matching \(preview.matches.count) recipes to your taste"))
        if preview.storeNames.isEmpty {
            lines.append(String(localized: "Scanning this week's deals near you"))
        } else {
            let names = AppFormat.list(Array(preview.storeNames.prefix(2)))
            lines.append(String(localized: "Scanning this week's deals at \(names)"))
        }
        if let budget = profile.weeklyBudget {
            lines.append(String(localized: "Fitting your \(Money.format(budget))/week budget"))
        } else {
            lines.append(String(localized: "Keeping every meal budget-friendly"))
        }
        return lines
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)
            ZStack {
                Circle().stroke(BW.beige, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: percent)
                    .stroke(BW.lemon, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                ZestView(pose: .wave, size: 112, talking: completed < tasks.count)
                    .offset(y: 4)
            }
            .frame(width: 184, height: 184)

            VStack(spacing: 6) {
                Text("\(Int((percent * 100).rounded()))%")
                    .font(.bw(size: 40, weight: .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: percent))
                    .foregroundStyle(BW.ink)
                Text(completed < tasks.count ? "Zesty is building your plan…" : "Your plan is ready!")
                    .font(.bw(.headline, weight: .bold))
                    .foregroundStyle(BW.inkSecondary)
                    .contentTransition(.opacity)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(tasks.enumerated()), id: \.offset) { i, task in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(i < completed ? BW.leaf : BW.beigeSoft)
                            if i < completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                            } else if i == completed {
                                ProgressView().controlSize(.mini).tint(BW.ink)
                            }
                        }
                        .frame(width: 28, height: 28)
                        Text(task)
                            .font(.bw(.subheadline, weight: i <= completed ? .semibold : .medium))
                            .foregroundStyle(i <= completed ? BW.ink : BW.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .opacity(i <= completed ? 1 : 0.4)
                }
            }
            .padding(20)
            .bwCard()
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
        .sensoryFeedback(.impact(weight: .light), trigger: completed)
        .task { await run() }
        .accessibilityElement(children: .combine)
    }

    private func run() async {
        let step: Double = reduceMotion ? 0.35 : 0.85
        for i in 0..<tasks.count {
            withAnimation(.easeInOut(duration: step)) { percent = Double(i + 1) / Double(tasks.count) }
            try? await Task.sleep(for: .seconds(step))
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { completed = i + 1 }
        }
        try? await Task.sleep(for: .milliseconds(650))
        if Task.isCancelled { return }
        onDone()
    }
}

/// The personalized plan built from onboarding answers.
struct PlanSummaryStep: View {
    let profile: UserProfile
    let preview: PlanPreview
    @State private var appear: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR PLAN")
                            .font(.bw(.caption, weight: .heavy)).tracking(1.4)
                            .foregroundStyle(BW.amber)
                        Text("Your Lemora plan is ready")
                            .font(.bw(size: 30, weight: .heavy, relativeTo: .title))
                            .tracking(-0.4)
                            .foregroundStyle(BW.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    ZestView(pose: .cheer, size: 82, hopEvery: 3.5)
                }

                HStack(spacing: 10) {
                    stat("\(preview.matches.count)", String(localized: "meals matched"))
                    stat("\(preview.dealCount)", String(localized: "deals this week"))
                    stat(preview.averagePerServing > 0 ? Money.format(preview.averagePerServing) : "—", String(localized: "avg / serving"))
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 12)

                if preview.matches.isEmpty {
                    MascotTip(text: String(localized: "Your filters are strict, so I'm keeping things extra safe. New recipes are added every week."))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("First meals picked for you").font(.bw(.headline, weight: .heavy)).foregroundStyle(BW.ink)
                        ScrollView(.horizontal) {
                            HStack(spacing: 12) {
                                ForEach(preview.matches.prefix(4)) { item in
                                    mealCard(item)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .contentMargins(.horizontal, 24, for: .scrollContent)
                        .padding(.horizontal, -24)
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 16)
                }

                VStack(spacing: 0) {
                    row("target", String(localized: "Goal"), profile.goal.title)
                    row("leaf", String(localized: "Diet"), profile.diets.map(\.title).sorted().joined(separator: ", "))
                    row("hand.raised", String(localized: "Avoiding"), avoidText)
                    row("storefront", String(localized: "Stores"), preview.storeNames.isEmpty ? "—" : preview.storeNames.joined(separator: ", "))
                    row("dollarsign.circle", String(localized: "Budget"), profile.weeklyBudget.map { String(localized: "\(Money.format($0))/week") } ?? String(localized: "Flexible"))
                    row("scalemass", String(localized: "Strategy"), profile.strategy.title, last: true)
                }
                .padding(.vertical, 4)
                .bwCard()
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)

                SamplePricesNote()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.1)) { appear = true }
        }
    }

    private var avoidText: String {
        let items = profile.allergyNames.sorted() + profile.dislikeNames
        return items.isEmpty ? String(localized: "Nothing") : items.joined(separator: ", ")
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.bw(.title2, weight: .heavy))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(BW.ink)
            Text(label)
                .font(.bw(.caption, weight: .semibold))
                .foregroundStyle(BW.inkSecondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(BW.lemonSoft, in: .rect(cornerRadius: 18))
    }

    private func mealCard(_ item: ScoredRecipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FoodImage(name: item.recipe.imageName, height: 120, radius: 18)
                .overlay(alignment: .topLeading) {
                    MatchBadge(percent: item.matchPercent, compact: true).padding(8)
                }
            Text(item.recipe.title)
                .font(.bw(.subheadline, weight: .bold))
                .foregroundStyle(BW.ink)
                .lineLimit(2, reservesSpace: true)
            Text("\(Money.format(item.price.perServing)) / serving")
                .font(.bw(.caption, weight: .semibold))
                .foregroundStyle(BW.leafDeep)
        }
        .frame(width: 170)
    }

    private func row(_ symbol: String, _ title: String, _ value: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(BW.amber).frame(width: 22)
                Text(title).font(.bw(.subheadline, weight: .semibold)).foregroundStyle(BW.inkSecondary)
                Spacer(minLength: 16)
                Text(value).font(.bw(.subheadline, weight: .bold)).foregroundStyle(BW.ink).multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            if !last { Divider().overlay(BW.hairline).padding(.leading, 50) }
        }
    }
}

/// Final "You're in!" moment after the paywall.
struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @State private var appear: Bool = false
    @State private var talking: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [BW.sun, BW.canvas], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            SunburstView().frame(width: 700, height: 700).offset(y: -120).opacity(0.9)

            VStack(spacing: 16) {
                Spacer()
                ZestBubble(text: store.isPremium ? String(localized: "Let's eat well and save!") : String(localized: "Let's find your first meal!"),
                           isTalking: $talking)
                    .offset(x: 56)
                ZestView(pose: .cheer, size: 190, hopEvery: 2.4, talking: talking)
                    .scaleEffect(appear ? 1 : 0.5)
                Text("You're in!")
                    .font(.bw(size: 46, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundStyle(BW.ink)
                    .padding(.top, 8)
                Text(store.isPremium
                     ? String(localized: "Lemora Premium is unlocked. Your full plan is waiting.")
                     : String(localized: "Your free plan is ready. You can unlock Premium anytime from Profile."))
                    .font(.bw(.body, weight: .regular))
                    .foregroundStyle(BW.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                if let ends = store.data.trialEndsAt, store.isPremium {
                    SoftChip(text: String(localized: "Free trial until \(AppFormat.longMonthDay(ends))"),
                             symbol: "calendar", fill: BW.leafSoft, foreground: BW.leafDeep)
                }
                Spacer()
                LemoraWordmark(size: 22, color: BW.ink.opacity(0.5))
                Button("Enter Lemora") { store.finishWelcome() }
                    .buttonStyle(ShineButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .opacity(appear ? 1 : 0)

            ConfettiView()
                .ignoresSafeArea()
        }
        .sensoryFeedback(.success, trigger: appear)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { appear = true }
        }
    }
}
