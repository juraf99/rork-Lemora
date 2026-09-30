import SwiftUI

/// Two-level streaks: weekly Savings Streak (money) and daily Wise Streak (habit).
/// A lemon plant grows instead of a flame.
struct StreaksView: View {
    @Environment(AppStore.self) private var store
    @State private var appear: Bool = false

    private var weeks: Int { store.savingsStreakWeeks }
    private var days: Int { store.wiseStreakDays }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Streaks").font(.system(.largeTitle, design: .rounded, weight: .heavy)).foregroundStyle(BW.ink)
                    Text("Small steps. Bigger savings.").font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                }
                savingsCard
                wiseCard
                growthCard
                countsCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(BW.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appear = true } }
    }

    private var savingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Savings Streak").font(.bw(.headline)).foregroundStyle(BW.ink)
                    Text(weeks == 1 ? String(localized: "1 week") : String(localized: "\(weeks) weeks"))
                        .font(.system(size: 44, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(BW.ink)
                    Text(store.savingsThisWeekDone ? String(localized: "This week is locked in!") : String(localized: "Keep it going this week!"))
                        .font(.bw(.subheadline, weight: .medium)).foregroundStyle(BW.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(GrowthStage.forWeeks(weeks).imageName)
                    .resizable().scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(appear ? 1 : 0.6)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let isCurrent = i == 6
                    let filled = isCurrent ? store.savingsThisWeekDone : (6 - i) <= (store.savingsThisWeekDone ? weeks - 1 : weeks)
                    VStack(spacing: 6) {
                        Circle()
                            .fill(filled ? BW.lemon : .clear)
                            .overlay(Circle().strokeBorder(filled ? BW.lemon : BW.leaf, lineWidth: 2))
                            .frame(width: 32, height: 32)
                            .scaleEffect(appear ? 1 : 0.3)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(i) * 0.05), value: appear)
                        Text(isCurrent ? String(localized: "Now") : "Wk \(i + 1)")
                            .font(.bw(.caption2, weight: .medium)).foregroundStyle(BW.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Savings streak: \(weeks) weeks"))
        }
        .padding(18)
        .background(
            LinearGradient(colors: [BW.leafSoft, BW.card], startPoint: .topTrailing, endPoint: .bottomLeading),
            in: .rect(cornerRadius: BW.cardRadius))
        .shadow(color: BW.ink.opacity(0.06), radius: 14, y: 6)
    }

    private var wiseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wise Streak").font(.bw(.headline)).foregroundStyle(BW.ink)
                    Text(days == 1 ? String(localized: "1 day") : String(localized: "\(days) days"))
                        .font(.system(size: 34, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(BW.ink)
                }
                Spacer()
                Text("Make it \(days + 1) tomorrow!").font(.bw(.caption, weight: .semibold)).foregroundStyle(BW.inkSecondary)
            }
            HStack(spacing: 0) {
                ForEach(Array(store.wiseWeek.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(day.active ? BW.leafSoft : BW.beigeSoft)
                            .overlay {
                                Image(BWImage.stageSprout).resizable().scaledToFit().padding(7)
                                    .opacity(day.active ? 1 : 0.25)
                                    .saturation(day.active ? 1 : 0)
                            }
                            .overlay(Circle().strokeBorder(day.isToday ? BW.leaf : .clear, lineWidth: 2))
                            .frame(width: 42, height: 42)
                        Text(day.label).font(.bw(.caption, weight: .semibold)).foregroundStyle(BW.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Wise streak: \(days) days"))
        }
        .padding(18)
        .bwCard()
    }

    private var growthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Watch your savings grow").font(.bw(.headline)).foregroundStyle(BW.ink)
            HStack {
                stage(BWImage.stageSprout, String(localized: "Day 1"), String(localized: "Sprout"), reached: days >= 1)
                Image(systemName: "arrow.right").foregroundStyle(BW.outline)
                stage(BWImage.stagePlant, String(localized: "Day 7"), String(localized: "Plant"), reached: days >= 7)
                Image(systemName: "arrow.right").foregroundStyle(BW.outline)
                stage(BWImage.stageLemon, String(localized: "Day 30"), String(localized: "Full lemon"), reached: days >= 30)
            }
        }
        .padding(18)
        .background(BW.beigeSoft, in: .rect(cornerRadius: BW.cardRadius))
    }

    private func stage(_ image: String, _ title: String, _ subtitle: String, reached: Bool) -> some View {
        VStack(spacing: 6) {
            Image(image).resizable().scaledToFit()
                .frame(width: 64, height: 64)
                .padding(6)
                .background(reached ? BW.leafSoft : BW.card, in: .circle)
                .opacity(reached ? 1 : 0.55)
            Text(title).font(.bw(.subheadline, weight: .bold)).foregroundStyle(BW.ink)
            Text(subtitle).font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var countsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What counts toward your Savings Streak")
                .font(.bw(.headline)).foregroundStyle(BW.ink)
                .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 6)
            countRow("frying.pan.fill", String(localized: "Cook a recipe with a deal"))
            Divider().overlay(BW.hairline).padding(.leading, 60)
            countRow("cart.fill", String(localized: "Add a deal to your grocery list"))
            Divider().overlay(BW.hairline).padding(.leading, 60)
            countRow("checkmark.circle.fill", String(localized: "Mark a meal 'Made with a deal'"))
        }
        .padding(.bottom, 6)
        .bwCard()
    }

    private func countRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(BW.leafDeep).frame(width: 28)
            Text(text).font(.bw(.body, weight: .medium)).foregroundStyle(BW.ink)
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 52)
    }
}
