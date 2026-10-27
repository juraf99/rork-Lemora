import SwiftUI

/// Daily streak: do one small thing a day (cook, use a deal, save a recipe).
struct StreaksView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var appear: Bool = false
    @State private var bob: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let milestones = [3, 7, 14, 30]
    private static let doneGreen = Color(hex: 0x4E9A3A)
    private static let doneSoft = Color(hex: 0xE3EEDB)
    private static let todoSoft = Color(hex: 0xFDF1C7)
    private static let ring = Color(hex: 0xF2D35B)

    private var days: Int { store.wiseStreakDays }
    private var doneToday: Bool { store.streakTodayDone }
    private var nextGoal: Int { Self.milestones.first { $0 > days } ?? 30 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                hero
                weekRow
                todaySection
                goalCard
                footer
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 32)
        }
        .background(Color(hex: 0xFAF6EE))
        .navigationTitle("Your streak")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { appear = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { bob = true }
            store.track("streak_opened", ["days": String(days)])
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 0) {
            OBArt.image(doneToday ? "zesty_love" : "zesty_impatient")
                .resizable().scaledToFit()
                .frame(width: 104, height: 104)
                .offset(y: bob ? -4 : 2)
                .accessibilityHidden(true)
            Text("\(days)")
                .font(.bw(size: 96, weight: .black))
                .tracking(-4)
                .monospacedDigit()
                .foregroundStyle(BW.ink)
                .contentTransition(.numericText())
                .scaleEffect(appear ? 1 : 0.7)
                .padding(.top, 6)
            Text("day streak")
                .font(.bw(size: 21, weight: .heavy))
                .foregroundStyle(BW.ink)
                .padding(.top, -2)
            Text(message)
                .font(.bw(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: 0x4B4A44))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .background(doneToday ? Self.doneSoft : Self.todoSoft, in: .rect(cornerRadius: 32))
        .animation(.easeInOut(duration: 0.4), value: doneToday)
        .accessibilityElement(children: .combine)
    }

    private var message: String {
        if doneToday { return String(localized: "Today counts. See you tomorrow for day \(days + 1).") }
        if days == 0 { return String(localized: "Do one thing today to start your streak.") }
        return String(localized: "Do one thing today to make it \(days + 1).")
    }

    // MARK: Week

    private var weekRow: some View {
        let week = store.wiseWeek
        let todayIndex = week.firstIndex { $0.isToday } ?? 0
        return HStack(spacing: 0) {
            ForEach(Array(week.enumerated()), id: \.offset) { i, day in
                VStack(spacing: 7) {
                    Text(day.label)
                        .font(.bw(size: 13, weight: day.isToday ? .heavy : .semibold))
                        .foregroundStyle(day.isToday ? BW.ink : Color(hex: 0x9A968E))
                    dot(done: day.active, today: day.isToday, future: i > todayIndex)
                        .scaleEffect(appear ? 1 : 0.4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(i) * 0.04), value: appear)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(.white, in: .rect(cornerRadius: 26))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("This week: \(week.filter(\.active).count) of 7 days"))
    }

    @ViewBuilder
    private func dot(done: Bool, today: Bool, future: Bool) -> some View {
        if done {
            Circle().fill(Self.doneGreen)
                .overlay(Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white))
                .frame(width: 36, height: 36)
        } else if today {
            Circle().fill(Color(hex: 0xFFFBEA))
                .overlay(Circle().strokeBorder(Self.ring, lineWidth: 3))
                .frame(width: 36, height: 36)
        } else if future {
            Circle().strokeBorder(Color(hex: 0xDDD6C8), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                .frame(width: 36, height: 36)
        } else {
            Circle().fill(Color(hex: 0xEFE8DA)).frame(width: 36, height: 36)
        }
    }

    // MARK: Today

    private enum Act: String, CaseIterable { case cook, deal, save }

    private var todaySection: some View {
        let doneActs = store.streakActionsToday
        return VStack(alignment: .leading, spacing: 0) {
            Text(doneToday ? String(localized: "Today: done ✓") : String(localized: "Today"))
                .font(.bw(size: 19, weight: .heavy)).foregroundStyle(BW.ink)
                .padding(.leading, 4)
            Text("Do any one of these. That's it.")
                .font(.bw(size: 14, weight: .medium)).foregroundStyle(Color(hex: 0x6E6A63))
                .padding(.leading, 4).padding(.top, 2).padding(.bottom, 12)
            VStack(spacing: 10) {
                ForEach(Act.allCases, id: \.self) { act in
                    actRow(act, on: doneActs.contains(act.rawValue), off: doneToday && !doneActs.contains(act.rawValue))
                }
            }
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private func actRow(_ act: Act, on: Bool, off: Bool) -> some View {
        let row = actLabel(act, on: on, off: off)
        switch act {
        case .cook:
            NavigationLink(value: Route.worthItAll) { row }.buttonStyle(BWPressableStyle()).disabled(doneToday)
        case .deal:
            NavigationLink(value: Route.stealsAll) { row }.buttonStyle(BWPressableStyle()).disabled(doneToday)
        case .save:
            Button { dismiss() } label: { row }.buttonStyle(BWPressableStyle()).disabled(doneToday)
        }
    }

    private func actLabel(_ act: Act, on: Bool, off: Bool) -> some View {
        let (icon, bg, title, sub): (String, Color, String, String) = {
            switch act {
            case .cook: return ("🍳", Self.todoSoft, String(localized: "Cook a meal"), String(localized: "Tap the pan on any recipe once it’s cooked"))
            case .deal: return ("🏷️", Self.doneSoft, String(localized: "Use a deal"), String(localized: "Add a meal with a deal to your list"))
            case .save: return ("♥", Color(hex: 0xFBE4DF), String(localized: "Save a recipe"), String(localized: "Swipe right on something you like"))
            }
        }()
        return HStack(spacing: 13) {
            Text(icon).font(.system(size: 22))
                .foregroundStyle(BW.ink)
                .frame(width: 46, height: 46)
                .background(bg, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bw(size: 16, weight: .heavy)).foregroundStyle(BW.ink)
                Text(sub).font(.bw(size: 13, weight: .medium)).foregroundStyle(Color(hex: 0x6E6A63))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if on {
                Text("✓ Done")
                    .font(.bw(size: 13.5, weight: .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(Self.doneGreen, in: .capsule)
            } else if !off {
                Text("Do it")
                    .font(.bw(size: 13.5, weight: .heavy)).foregroundStyle(BW.ink)
                    .padding(.horizontal, 15).padding(.vertical, 8)
                    .background(Self.ring, in: .capsule)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.white, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(on ? Self.doneGreen : Color.clear, lineWidth: 2))
        .shadow(color: BW.ink.opacity(0.05), radius: 5, y: 2)
        .opacity(off ? 0.5 : 1)
    }

    // MARK: Goal

    private var goalCard: some View {
        let left = max(0, nextGoal - days)
        let progress = min(1, Double(days) / Double(nextGoal))
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Next goal: \(nextGoal) days").font(.bw(size: 17, weight: .heavy)).foregroundStyle(BW.ink)
                Spacer(minLength: 4)
                Text(left == 1 ? String(localized: "1 more day") : String(localized: "\(left) more days"))
                    .font(.bw(size: 13.5, weight: .bold)).foregroundStyle(Color(hex: 0x3E7F2E))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0xEFE8DA))
                    Capsule().fill(Self.doneGreen)
                        .frame(width: max(12, geo.size.width * (appear ? progress : 0)))
                }
            }
            .frame(height: 12)
            .padding(.top, 12)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appear)
            HStack(spacing: 6) {
                ForEach(Self.milestones, id: \.self) { n in
                    let reached = days >= n
                    let isNext = n == nextGoal && !reached
                    Text(reached ? "✓ \(n) days" : "\(n) days")
                        .font(.bw(size: 12.5, weight: .heavy))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(reached ? Color.white : (isNext ? BW.ink : Color(hex: 0x9A968E)))
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(reached ? Self.doneGreen : (isNext ? Self.todoSoft : Color(hex: 0xF4EFE5)), in: Capsule())
                        .overlay(Capsule().strokeBorder(isNext ? Self.ring : Color.clear, lineWidth: 2))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 14)
        }
        .padding(18)
        .background(.white, in: .rect(cornerRadius: 26))
        .padding(.top, 8)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("🏆 Best: \(max(store.bestWiseStreak, days)) days")
            Spacer(minLength: 4)
            Text("Miss a day and it restarts at 0")
                .multilineTextAlignment(.trailing)
        }
        .font(.bw(size: 13.5, weight: .semibold))
        .foregroundStyle(Color(hex: 0x6E6A63))
        .padding(.horizontal, 6)
    }
}

extension AppStore {
    private static let streakKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Something that counts was done today (cooked, used a deal, saved a recipe…).
    var streakTodayDone: Bool {
        data.activeDays.contains(Self.streakKeyFormatter.string(from: .now))
    }

    /// Which of the three streak actions were done today: "cook", "deal", "save".
    var streakActionsToday: Set<String> {
        let cal = Calendar.current
        var out = Set<String>()
        if data.cookLogs.contains(where: { cal.isDateInToday($0.date) }) { out.insert("cook") }
        if data.savingsActions.contains(where: { cal.isDateInToday($0.date) && $0.kind == .addedDealToList }) { out.insert("deal") }
        if data.saved.contains(where: { cal.isDateInToday($0.savedAt) }) { out.insert("save") }
        return out
    }

    /// Longest run of consecutive active days ever.
    var bestWiseStreak: Int {
        let f = Self.streakKeyFormatter
        let dates = Set(data.activeDays).compactMap { f.date(from: $0) }.sorted()
        let cal = Calendar(identifier: .gregorian)
        var best = 0, run = 0
        var prev: Date? = nil
        for d in dates {
            if let p = prev, let next = cal.date(byAdding: .day, value: 1, to: p), cal.isDate(next, inSameDayAs: d) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            prev = d
        }
        return best
    }
}
