import SwiftUI
import StoreKit

// MARK: - Thanks

struct OBThanksScreen: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZestyMascot(mood: .love, size: 150, seedKey: "th")
            OBText("Thanks for trusting us.", 32, 800, tracking: -0.03, align: .center)
                .padding(.top, 22)
                .obIn(delay: 0.2, duration: 0.4)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("🎯").font(.system(size: 16)).frame(width: 34, height: 34).background(OB.sunSoft, in: .circle)
                    Text("Personalized to your goals").font(OB.font(16, 800)).foregroundStyle(OB.ink)
                }
                OBText("Your answers help Lemora tailor your meals, recommendations and savings around what matters most to you.", 13.5, 500, color: OB.muted)
                    .lineSpacing(3)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: .rect(cornerRadius: 24))
            .shadow(color: OB.ink.opacity(0.07), radius: 10, x: 0, y: 6)
            .padding(.top, 22)
            .obIn(delay: 0.35, duration: 0.4)
            Spacer(minLength: 0)
            OBPrimaryButton(title: "CONTINUE") { m.go(.notif) }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(OB.sun(rx: 1.1, ry: 0.6, cy: 0.34, stop: 0.62))
    }
}

// MARK: - Notifications primer

struct OBNotifScreen: View {
    @Environment(OnboardingModel.self) private var m
    private let notifs = [("now", "Chicken is a great price near you this week."),
                          ("2h ago", "3 meals you liked just got cheaper."),
                          ("Sun", "Your weekly picks are ready.")]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { tl in
            let sad = tl.date < m.sadUntil
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    OBText("Stay on track with Lemora notifications.", 30, 800, tracking: -0.03)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ZestyMascot(mood: sad ? .sad : .talking, size: 64, seedKey: "nt")
                        .id(sad ? "nts" : "nt")
                }
                OBText("Only useful ones: price drops on meals you like and your weekly picks.", 14, 500, color: OB.muted)
                    .lineSpacing(3)
                    .padding(.top, 8)
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    Text("9:41").font(OB.font(52, 300)).tracking(-1).foregroundStyle(.white.opacity(0.9))
                    Text("Thursday").font(OB.font(12, 600)).foregroundStyle(.white.opacity(0.6)).padding(.top, 4).padding(.bottom, 18)
                    VStack(spacing: 8) {
                        ForEach(Array(notifs.enumerated()), id: \.offset) { i, n in
                            HStack(alignment: .top, spacing: 10) {
                                OBArt.image("zesty_base").resizable().scaledToFit().frame(width: 24, height: 25)
                                    .frame(width: 34, height: 34).background(OB.sunSoft, in: .rect(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Lemora").font(OB.font(12, 800)).foregroundStyle(OB.ink)
                                        Spacer()
                                        Text(n.0).font(OB.font(12, 600)).foregroundStyle(Color(hex: 0x7C847D))
                                    }
                                    Text(n.1).font(OB.font(12.5, 600)).foregroundStyle(Color(hex: 0x2A332E))
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 11)
                            .background(.white.opacity(0.92), in: .rect(cornerRadius: 18))
                            .modifier(OBAppear(kind: .slide, delay: 0.2 + Double(i) * 0.35, duration: 0.45))
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.top, 26).padding(.bottom, 20)
                .background(LinearGradient(colors: [Color(hex: 0x1F5A45), OB.ink], startPoint: UnitPoint(x: 0.3, y: 0), endPoint: UnitPoint(x: 0.7, y: 1)),
                            in: .rect(cornerRadius: 30))
                Spacer(minLength: 0)
                GeometryReader { geo in
                    let unit = (geo.size.width - 10) / 2.3
                    HStack(spacing: 10) {
                        Button { m.notifDeny() } label: {
                            Text("DON’T ALLOW").font(OB.font(15, 800)).foregroundStyle(OB.ink)
                                .frame(width: unit).padding(.vertical, 16)
                                .background(.white, in: .capsule)
                                .overlay(Capsule().strokeBorder(OB.border, lineWidth: 1.5))
                        }
                        Button { m.notifAllow() } label: {
                            Text("ALLOW").font(OB.font(15, 800)).foregroundStyle(OB.ink)
                                .frame(width: unit * 1.3).padding(.vertical, 16)
                                .background(OB.lemon, in: .capsule)
                                .shadow(color: OB.lemon.opacity(0.4), radius: 8, x: 0, y: 6)
                        }
                    }
                    .buttonStyle(OBPress())
                }
                .frame(height: 52)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(OB.cream.ignoresSafeArea())
    }
}

// MARK: - Ready

struct OBReadyScreen: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZestyMascot(mood: .idea, size: 150, seedKey: "rd")
            OBText("Time to generate your custom plan.", 34, 800, tracking: -0.035, align: .center)
                .padding(.top, 24)
                .obIn(delay: 0.15, duration: 0.4)
            OBText("I’ll use everything you told me. It only takes a few seconds.", 14.5, 500, color: OB.muted, align: .center)
                .lineSpacing(3)
                .frame(maxWidth: 290)
                .padding(.top, 10)
                .obIn(delay: 0.3, duration: 0.4)
            Spacer(minLength: 0)
            OBPrimaryButton(title: "CONTINUE") { m.go(.generating) }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(OB.sun(rx: 1.1, ry: 0.6, cy: 0.38, stop: 0.62))
    }
}

// MARK: - Generating

struct OBGeneratingScreen: View {
    @Environment(OnboardingModel.self) private var m

    private var steps: [String] {
        let a = m.a
        var g = ["Personalizing meals to your goal: \(m.goalInfo.label)",
                 a.diets.contains("none") ? "No diet restrictions to apply" : "Matching your diet: " + m.dietList.joined(separator: " + "),
                 a.noAllergy || a.allergies.isEmpty ? "No allergens to remove" : "Removing \(a.allergies.count) allergen\(a.allergies.count > 1 ? "s" : "")"]
        if !a.dislikes.isEmpty { g.append("Avoiding \(a.dislikes.count) disliked food\(a.dislikes.count > 1 ? "s" : "")") }
        if let loc = m.currentLocation {
            g.append("Finding \(a.stores.count) store\(a.stores.count != 1 ? "s" : "") near \(loc.postal)")
        } else {
            g.append("Finding stores near you")
        }
        g.append(a.noBudget ? "No strict budget, optimizing for value" : "Applying your \(OnboardingModel.money(Double(a.budget)))/week budget")
        g.append("Optimizing for " + m.strategyTitle)
        return g
    }

    var body: some View {
        let pct = m.pct
        let list = steps
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().stroke(Color(hex: 0xEFE6CF), lineWidth: 10)
                    Circle().trim(from: 0, to: CGFloat(pct) / 100)
                        .stroke(OB.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    HStack(alignment: .top, spacing: 0) {
                        Text("\(pct)").font(OB.font(58, 800)).tracking(-2.3).monospacedDigit()
                        Text("%").font(OB.font(24, 800)).padding(.top, 6)
                    }
                    .foregroundStyle(OB.ink)
                }
                .frame(width: 180, height: 180)
                .padding(8)
                Text(pct >= 100 ? "Your plan is ready!" : "Building your plan…")
                    .font(OB.font(22, 800)).tracking(-0.44).foregroundStyle(OB.ink)
                    .padding(.top, 18)
            }
            VStack(spacing: 8) {
                ForEach(Array(list.enumerated()), id: \.offset) { i, text in
                    let on = pct >= Int((Double(i + 1) * 100 / Double(list.count + 1)).rounded())
                    HStack(spacing: 11) {
                        Text("✓").font(OB.font(11, 800)).foregroundStyle(on ? .white : .clear)
                            .frame(width: 22, height: 22).background(on ? OB.green : OB.pill, in: .circle)
                        Text(text).font(OB.font(13.5, 700)).foregroundStyle(OB.ink).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .background(.white, in: .rect(cornerRadius: 16))
                    .shadow(color: OB.ink.opacity(0.04), radius: 5, x: 0, y: 2)
                    .opacity(on ? 1 : 0.35)
                    .offset(x: on ? 0 : 6)
                    .animation(.easeInOut(duration: 0.3), value: on)
                }
            }
            .padding(.top, 22)
            Spacer(minLength: 0)
            Button { m.go(.savings) } label: {
                Text("SEE MY RESULTS").font(OB.font(17, 800))
                    .foregroundStyle(pct >= 100 ? OB.ink : OB.disabledText)
                    .frame(maxWidth: .infinity).padding(.vertical, 17)
                    .background(pct >= 100 ? OB.lemon : OB.track, in: .capsule)
                    .opacity(pct >= 100 ? 1 : 0.7)
            }
            .buttonStyle(OBPress())
            .disabled(pct < 100)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(OB.cream.ignoresSafeArea())
        .onAppear { if m.pct == 0 { m.startGen() } }
    }
}

// MARK: - Savings

struct OBSavingsScreen: View {
    @Environment(OnboardingModel.self) private var m
    @State private var grow = false

    var body: some View {
        let est = m.estimate
        let bars: [(String, Int, CGFloat)] = [("Week", est.weekly, 0.16), ("Month", est.monthly, 0.40), ("Year", est.annual, 1)]
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("YOUR POTENTIAL SAVINGS").font(OB.font(12, 800)).tracking(1.44).foregroundStyle(OB.lemon)
                Spacer()
                ZestyMascot(mood: .celebrating, size: 64, seedKey: "sv")
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(OnboardingModel.money(Double(est.annual) * m.countProgress))
                    .font(OB.font(78, 800)).tracking(-3.9).foregroundStyle(.white).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("per year, with regular use").font(OB.font(18, 700)).foregroundStyle(.white.opacity(0.8)).padding(.top, 6)
                HStack(spacing: 8) {
                    chip(OnboardingModel.money(Double(est.weekly)), " / week")
                    chip(OnboardingModel.money(Double(est.monthly)), " / month")
                }
                .padding(.top, 16)
            }
            .padding(.top, -20)
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { i, b in
                        VStack(spacing: 6) {
                            Spacer(minLength: 0)
                            Text(OnboardingModel.money(Double(b.1))).font(OB.font(13, 800)).foregroundStyle(i == 2 ? OB.lemon : .white)
                            RoundedRectangle(cornerRadius: 14)
                                .fill(i == 2 ? OB.lemon : Color.white.opacity(0.18 + Double(i) * 0.1))
                                .frame(height: max(8, (geo.size.height - 44) * b.2))
                                .scaleEffect(y: grow ? 1 : 0, anchor: .bottom)
                                .animation(.timingCurve(0.3, 0.7, 0.3, 1, duration: 0.7).delay(0.3 + Double(i) * 0.2), value: grow)
                            Text(b.0).font(OB.font(12, 700)).foregroundStyle(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 26)
            .frame(minHeight: 150)
            Text("Estimate based on \(m.a.noBudget ? "a typical budget for \(m.a.household) people" : "your \(OnboardingModel.money(Double(m.a.budget)))/week budget"), \(m.a.stores.count) store\(m.a.stores.count != 1 ? "s" : "") and \(m.strategyTitle.lowercased()) shopping. Actual savings depend on the deals available near you.")
                .font(OB.font(11.5, 500)).foregroundStyle(.white.opacity(0.6)).lineSpacing(2)
                .padding(.top, 16)
            Button { m.go(.reminder) } label: {
                Text("CONTINUE").font(OB.font(17, 800)).foregroundStyle(OB.ink)
                    .frame(maxWidth: .infinity).padding(.vertical, 17)
                    .background(OB.lemon, in: .capsule)
            }
            .buttonStyle(OBPress())
            .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background {
            ZStack(alignment: .top) {
                OB.ink
                RadialGradient(colors: [OB.lemon.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 161)
                    .frame(width: 520, height: 520)
                    .offset(y: -20)
            }
            .ignoresSafeArea()
        }
        .onAppear { grow = true; if m.countProgress == 0 { m.startCount() } }
    }

    private func chip(_ value: String, _ unit: String) -> some View {
        (Text(value).font(OB.font(14, 800)) + Text(unit).font(OB.font(14, 600)).foregroundColor(.white.opacity(0.7)))
            .foregroundStyle(.white)
            .padding(.horizontal, 13).padding(.vertical, 8)
            .background(.white.opacity(0.1), in: .capsule)
    }
}

// MARK: - Goal reminder

struct OBReminderScreen: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        let goal = m.goalInfo
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack(alignment: .bottomTrailing) {
                ZestyMascot(mood: .happy, size: 140, seedKey: "rm")
                Text(goal.icon).font(.system(size: 24))
                    .frame(width: 52, height: 52)
                    .background(.white, in: .circle)
                    .shadow(color: OB.ink.opacity(0.12), radius: 8, x: 0, y: 6)
                    .offset(x: 18, y: -6)
                    .obPop(delay: 0.4, duration: 0.45)
            }
            Text("YOUR GOAL · \(goal.label.uppercased())").font(OB.font(12, 800)).tracking(1.44).foregroundStyle(OB.green)
                .multilineTextAlignment(.center)
                .padding(.top, 26)
            OBText(OBCatalog.reminder[m.a.goal] ?? "", 30, 800, tracking: -0.03, align: .center)
                .padding(.top, 10)
                .obIn(delay: 0.2, duration: 0.4)
            HStack(spacing: 8) {
                Text("\(OnboardingModel.money(Double(m.estimate.annual)))/yr").foregroundStyle(OB.lemon)
                Text("potential savings included").foregroundStyle(.white)
            }
            .font(OB.font(14, 800))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(OB.ink, in: .capsule)
            .padding(.top, 18)
            .obIn(delay: 0.35, duration: 0.4)
            Spacer(minLength: 0)
            OBPrimaryButton(title: "CONTINUE") { m.go(.plan) }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(OB.sun(rx: 1.1, ry: 0.6, cy: 0.36, stop: 0.62))
    }
}

// MARK: - Plan summary

struct OBPlanScreen: View {
    @Environment(OnboardingModel.self) private var m
    @Environment(AppStore.self) private var store

    var body: some View {
        let est = m.estimate
        let a = m.a
        let rows: [(String, String, String)] = [
            ("🎯", "Goal", m.goalInfo.label),
            ("🥗", "Diet", m.dietList.joined(separator: " + ")),
            ("🚫", "Allergies", a.noAllergy || a.allergies.isEmpty ? "None" : a.allergies.map { m.allergenName($0) }.joined(separator: ", ")),
            ("👎", "Dislikes", a.dislikes.isEmpty ? "None" : a.dislikes.map(\.name).joined(separator: ", ")),
            ("🍽️", "Meals", m.mealList.joined(separator: ", ")),
            ("🛒", "Stores", a.stores.isEmpty ? "None yet" : a.stores.joined(separator: ", ")),
            ("💵", "Budget", a.noBudget ? "No strict budget" : OnboardingModel.money(Double(a.budget)) + " / week"),
            ("🧭", "Strategy", m.strategyTitle),
        ]
        let picks = Array(store.planPreview(for: m.makeProfile(base: store.data.profile)).matches.prefix(3))
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                OBBackButton(size: 38) { m.go(OnboardingModel.steps.last ?? .strategy) }
                Spacer()
            }
            .padding(.bottom, 6)
            HStack(spacing: 10) {
                ZestyMascot(mood: .idle, size: 54, seedKey: "pl")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your Lemora plan").font(OB.font(26, 800)).tracking(-0.78).foregroundStyle(OB.ink)
                    OBText("Built from your answers. You can change anything later.", 13, 500, color: OB.sub)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Estimated savings").font(OB.font(12, 700)).foregroundStyle(.white.opacity(0.7))
                            (Text(OnboardingModel.money(Double(est.annual))).font(OB.font(30, 800)).foregroundColor(OB.lemon)
                             + Text(" / year").font(OB.font(15, 800)).foregroundColor(.white.opacity(0.75)))
                                .tracking(-0.9)
                        }
                        Spacer()
                        Text("\(OnboardingModel.money(Double(est.weekly))) / week").font(OB.font(12, 700)).foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 18).padding(.vertical, 16)
                    .background(OB.ink, in: .rect(cornerRadius: 22))

                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                            HStack(spacing: 8) {
                                Text(r.0).font(.system(size: 16)).frame(width: 22)
                                Text(r.1).font(OB.font(12.5, 600)).foregroundStyle(OB.sub).frame(width: 78, alignment: .leading)
                                Text(r.2).font(OB.font(13.5, 700)).foregroundStyle(OB.ink)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(.vertical, 11)
                            .overlay(alignment: .top) { if i > 0 { Rectangle().fill(OB.divider).frame(height: 1) } }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    .background(.white, in: .rect(cornerRadius: 22))
                    .shadow(color: OB.ink.opacity(0.05), radius: 5, x: 0, y: 2)

                    if !picks.isEmpty {
                        Text("First picks for you").font(OB.font(14, 800)).foregroundStyle(OB.ink).padding(.top, 4).padding(.horizontal, 2)
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(picks, id: \.id) { p in
                                VStack(alignment: .leading, spacing: 0) {
                                    Color(hex: 0xEFE6D2)
                                        .frame(height: 78)
                                        .overlay { Image(p.recipe.imageName).resizable().scaledToFill() }
                                        .clipped()
                                    Text(p.recipe.title).font(OB.font(11, 700)).foregroundStyle(OB.ink).lineSpacing(1)
                                        .lineLimit(3)
                                        .padding(.horizontal, 8).padding(.top, 7).padding(.bottom, 9)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white)
                                .clipShape(.rect(cornerRadius: 16))
                                .shadow(color: OB.ink.opacity(0.06), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4).padding(.top, 2).padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -4)
            .padding(.top, 14)
            OBPrimaryButton(title: "CONTINUE") { m.go(isSignedIn ? (store.isPremium ? .done : .paywall) : .account) }
                .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(OB.cream.ignoresSafeArea())
    }

    /// Already signed in (e.g. signed in first, then answered): skip account creation.
    private var isSignedIn: Bool { store.data.account?.userId != nil }
}

// MARK: - Account

struct OBAccountScreen: View {
    @Environment(OnboardingModel.self) private var m
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                OBBackButton(size: 38) { m.go(.plan) }
                Spacer()
            }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                ZestyMascot(mood: .talking, size: 110, seedKey: "ac")
                OBText("Save your Lemora plan", 32, 800, tracking: -0.03, align: .center).padding(.top, 18)
                OBText("Create your account to keep your preferences, recommendations and personalized savings.", 14.5, 500, color: OB.muted, align: .center)
                    .lineSpacing(3)
                    .frame(maxWidth: 300)
                    .padding(.top, 8)
                HStack(spacing: 8) {
                    Text("●").foregroundStyle(OB.green)
                    Text("\(OnboardingModel.money(Double(m.estimate.annual)))/yr plan ready · \(m.goalInfo.label)").foregroundStyle(OB.ink)
                }
                .font(OB.font(12.5, 700))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.white, in: .capsule)
                .shadow(color: OB.ink.opacity(0.06), radius: 5, x: 0, y: 2)
                .padding(.top, 16)
                if let e = m.errorText {
                    OBText(e, 12.5, 600, color: OB.red, align: .center).padding(.top, 10)
                }
            }
            Spacer(minLength: 0)
            OBAuthButtons(apple: { m.authCtx = .new; m.authApple(store) },
                          google: { m.authCtx = .new; m.authGoogle(store) },
                          emailAction: { m.authCtx = .new; m.emailMode = .create; m.resetSent = false; m.go(.email) },
                          busy: m.busy)
            HStack(spacing: 4) {
                Text("Already have an account?").font(OB.font(13.5, 500)).foregroundStyle(OB.muted)
                Button { m.authCtx = .merge; m.go(.signin) } label: {
                    Text("Sign In").font(OB.font(13.5, 800)).foregroundStyle(OB.ink)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(OB.cream.ignoresSafeArea())
    }
}

// MARK: - Email

struct OBEmailScreen: View {
    @Environment(OnboardingModel.self) private var m
    @Environment(AppStore.self) private var store
    @FocusState private var focus: Int?

    private var pwScore: Int {
        let p = m.password
        var s = 0
        if p.count >= 8 { s += 1 }
        if p.rangeOfCharacter(from: .uppercaseLetters) != nil { s += 1 }
        if p.rangeOfCharacter(from: .decimalDigits) != nil { s += 1 }
        if p.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil { s += 1 }
        return min(4, s)
    }

    var body: some View {
        @Bindable var m = m
        let create = m.emailMode == .create
        VStack(alignment: .leading, spacing: 0) {
            OBBackButton(size: 38) { m.go(m.authCtx == .new ? .account : .signin) }
            OBText(create ? "Create your account" : "Sign in with email", 30, 800, tracking: -0.03).padding(.top, 22)
            OBText(create ? "Your plan is saved to this account." : "Use the email you signed up with.", 14, 500, color: OB.muted).padding(.top, 6)
            VStack(alignment: .leading, spacing: 10) {
                field(TextField("", text: $m.email, prompt: Text("Email").foregroundStyle(OB.faint))
                        .keyboardType(.emailAddress).textContentType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focus, equals: 0).submitLabel(.next).onSubmit { focus = 1 })
                field(SecureField("", text: $m.password, prompt: Text(create ? "Create a password" : "Password").foregroundStyle(OB.faint))
                        .textContentType(create ? .newPassword : .password)
                        .focused($focus, equals: 1).submitLabel(.go).onSubmit { m.emailSubmit(store) })
                if create {
                    HStack(spacing: 5) {
                        ForEach(0..<4, id: \.self) { i in
                            Capsule().fill(i < pwScore ? [OB.red, OB.orange, OB.lemon, OB.green][pwScore - 1] : OB.track).frame(height: 4)
                        }
                    }
                    .padding(.horizontal, 6)
                    .animation(.easeInOut(duration: 0.2), value: pwScore)
                    Text("At least 8 characters. We’ll send a code to verify your email.")
                        .font(OB.font(11.5, 500)).foregroundStyle(OB.faint).padding(.horizontal, 8)
                } else {
                    HStack {
                        Spacer()
                        Button("Forgot password?") { m.forgotPassword(store) }
                            .font(OB.font(13, 700)).foregroundStyle(OB.green).buttonStyle(.plain)
                    }
                }
                if m.resetSent {
                    Text("If an account exists for \(m.email), we sent a reset link.")
                        .font(OB.font(12.5, 600)).foregroundStyle(OB.mintText)
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OB.mint, in: .rect(cornerRadius: 14))
                }
                if let e = m.errorText {
                    OBText(e, 12.5, 600, color: OB.red).padding(.horizontal, 8)
                }
                OBPrimaryButton(title: create ? "Create account" : "Sign in", loading: m.busy) { m.emailSubmit(store) }
                    .padding(.top, 6)
            }
            .padding(.top, 22)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text(create ? "Already have an account?" : "New to Lemora?").font(OB.font(13.5, 500)).foregroundStyle(OB.muted)
                Button {
                    if create && m.authCtx == .new { m.authCtx = .merge }
                    m.emailMode = create ? .signin : .create
                    m.resetSent = false
                    m.errorText = nil
                } label: {
                    Text(create ? "Sign in" : "Create account").font(OB.font(13.5, 800)).foregroundStyle(OB.ink)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(OB.cream.ignoresSafeArea())
        .onAppear { focus = 0 }
    }

    private func field(_ content: some View) -> some View {
        content
            .font(OB.font(15, 600))
            .foregroundStyle(OB.ink)
            .padding(.horizontal, 18).padding(.vertical, 15)
            .background(.white, in: .capsule)
            .overlay(Capsule().strokeBorder(OB.inputBorder, lineWidth: 1.5))
    }
}

// MARK: - Email code

struct OBVerifyScreen: View {
    @Environment(OnboardingModel.self) private var m
    @Environment(AppStore.self) private var store
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var m = m
        VStack(alignment: .leading, spacing: 0) {
            OBBackButton(size: 38) { m.go(.email) }
            OBText("Check your email", 30, 800, tracking: -0.03).padding(.top, 22)
            OBText("Enter the 6-digit code we sent to \(m.email).", 14, 500, color: OB.muted).padding(.top, 6)
            VStack(alignment: .leading, spacing: 10) {
                TextField("", text: Binding(get: { m.code }, set: { m.code = String($0.filter(\.isNumber).prefix(6)) }),
                          prompt: Text("123456").foregroundStyle(OB.faint))
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(OB.font(22, 800))
                    .tracking(8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(OB.ink)
                    .focused($focused)
                    .padding(.vertical, 15)
                    .background(.white, in: .capsule)
                    .overlay(Capsule().strokeBorder(OB.inputBorder, lineWidth: 1.5))
                if let e = m.errorText {
                    OBText(e, 12.5, 600, color: OB.red).padding(.horizontal, 8)
                }
                if m.resetSent {
                    Text("We sent you a new code.").font(OB.font(12.5, 600)).foregroundStyle(OB.mintText)
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OB.mint, in: .rect(cornerRadius: 14))
                }
                OBPrimaryButton(title: "Verify email", enabled: m.code.count == 6, loading: m.busy) { m.verifyCode(store) }
                    .padding(.top, 6)
            }
            .padding(.top, 22)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text("Didn’t get it?").font(OB.font(13.5, 500)).foregroundStyle(OB.muted)
                Button { m.resendCode() } label: {
                    Text("Send a new code").font(OB.font(13.5, 800)).foregroundStyle(OB.ink)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(OB.cream.ignoresSafeArea())
        .onAppear { focused = true; m.resetSent = false }
        .onChange(of: m.code) { _, v in if v.count == 6 { m.verifyCode(store) } }
    }
}

// MARK: - Paywall

struct OBPaywallScreen: View {
    @Environment(OnboardingModel.self) private var m
    @Environment(AppStore.self) private var store
    @State private var purchasing = false
    @State private var message: String?
    @State private var showPrivacy = false

    private var sub: SubscriptionService { store.subscription }
    private var annual: Bool { m.a.plan == "annual" }
    private var annualPrice: String { sub.annual?.displayPrice ?? "$39.99" }
    private var monthlyPrice: String { sub.monthly?.displayPrice ?? "$9.99" }
    private var annualValue: Double { sub.annual.map(SubscriptionService.amount) ?? 39.99 }
    private var monthlyValue: Double { sub.monthly.map(SubscriptionService.amount) ?? 9.99 }
    private var currencyCode: String { sub.annual?.priceFormatStyle.currencyCode ?? (m.currency) }
    /// Free-trial days on the yearly plan (from the App Store product), when this Apple ID is eligible.
    private var trialDays: Int? {
        guard let product = sub.annual else { return nil }
        guard sub.isEligibleForTrial, let days = SubscriptionService.trialDays(of: product), days > 0 else { return nil }
        return days
    }
    private var savePercent: Int { max(0, Int(((1 - annualValue / (monthlyValue * 12)) * 100).rounded())) }
    private var perMonth: String { (annualValue / 12).formatted(.currency(code: currencyCode).presentation(.narrow)) }

    private var timeline: [(String, String, String)] {
        if annual, let days = trialDays {
            return [("🔓", "Today", "Everything unlocked: unlimited swipes, every deal"),
                    ("🔔", "Day \(max(1, days - 2))", "We’ll remind you before the trial ends"),
                    ("⭐", "Day \(days)", "\(annualPrice)/year starts. Cancel anytime before.")]
        }
        if annual {
            return [("🔓", "Today", "Everything unlocked · \(annualPrice) billed"),
                    ("🔔", "Every year", "Renews at \(annualPrice)"),
                    ("⭐", "Anytime", "Cancel in Settings in two taps")]
        }
        return [("🔓", "Today", "Everything unlocked · \(monthlyPrice) billed"),
                ("🔔", "Every month", "Renews at \(monthlyPrice)"),
                ("⭐", "Anytime", "Cancel in Settings in two taps")]
    }

    private var cta: String {
        if annual { return trialDays == 7 ? "START MY FREE WEEK" : (trialDays.map { "START MY \($0)-DAY FREE TRIAL" } ?? "Continue · \(annualPrice)/yr") }
        return "Continue · \(monthlyPrice)/mo"
    }

    private var legal: String {
        if annual, let days = trialDays { return "Free for \(days) days, then \(annualPrice) \(currencyCode)/year. Cancel anytime." }
        return annual ? "\(annualPrice) \(currencyCode)/year. Renews until cancelled." : "\(monthlyPrice) \(currencyCode)/month. Renews until cancelled."
    }

    var body: some View {
        VStack(spacing: 0) {
            hero
            VStack(alignment: .leading, spacing: 0) {
                Text("✦ LEMORA PREMIUM").font(OB.font(11, 800)).tracking(0.44).foregroundStyle(OB.lemon)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(OB.ink, in: .capsule)
                    .obIn(delay: 0.1, duration: 0.4)
                OBText("Unlock Your Full Plan Today", 29, 800, tracking: -0.03).padding(.top, 10).obIn(delay: 0.18, duration: 0.4)
                OBText("Tailored to your goal, your diet and \(m.a.stores.count) store\(m.a.stores.count != 1 ? "s" : "") near you.", 13.5, 400, color: OB.muted)
                    .padding(.top, 6).obIn(delay: 0.24, duration: 0.4)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(timeline.enumerated()), id: \.offset) { i, r in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Text(r.0).font(.system(size: 13)).frame(width: 30, height: 30)
                                    .background(i == 0 ? OB.lemon : OB.pill, in: .circle)
                                if i < timeline.count - 1 {
                                    Capsule()
                                        .fill(i == 0 ? AnyShapeStyle(LinearGradient(colors: [OB.lemon, OB.track], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(OB.track))
                                        .frame(width: 2)
                                        .frame(minHeight: 12)
                                        .padding(.vertical, 3)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.1).font(OB.font(14, 800)).foregroundStyle(OB.ink)
                                Text(r.2).font(OB.font(12, 400)).foregroundStyle(OB.sub).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, 12)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: .rect(cornerRadius: 22))
                .shadow(color: OB.ink.opacity(0.06), radius: 6, x: 0, y: 2)
                .padding(.top, 16)
                .obIn(delay: 0.3, duration: 0.4)
                .animation(.snappy, value: m.a.plan)

                Spacer(minLength: 12)

                OBWeightedRow(weights: [1.25, 1], spacing: 10) {
                    planCard(id: "annual", name: "Yearly", price: annualPrice, unit: "\(perMonth) / month",
                             terms: trialDays.map { "\($0) days free" } ?? "Billed yearly",
                             badge: savePercent > 0 ? "BEST VALUE · −\(savePercent)%" : "BEST VALUE")
                    planCard(id: "monthly", name: "Monthly", price: monthlyPrice, unit: "per month", terms: "No trial", badge: nil)
                }
                .padding(.top, 11)
                .obIn(delay: 0.38, duration: 0.4)

                OBPrimaryButton(title: cta, shine: true, loading: purchasing) { Task { await purchase() } }
                    .padding(.top, 14)
                if let message {
                    Text(message).font(OB.font(11.5, 600)).foregroundStyle(OB.red)
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 8)
                }
                Text(legal).font(OB.font(11, 400)).foregroundStyle(OB.faint).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.top, 10)
                HStack(spacing: 18) {
                    Button("Restore") { Task { await restore() } }
                    Button("Terms & Privacy") { showPrivacy = true }
                }
                .font(OB.font(11.5, 700))
                .foregroundStyle(OB.sub)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .padding(.top, -6)
        }
        .background(OB.cream.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            // TEMPORARY (beta): tester bypass for the hard paywall. Remove before public release.
            Button {
                store.enableTesterBypass()
                m.go(.done)
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(OB.ink.opacity(0.55))
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: .circle)
            }
            .padding(.top, 4)
            .padding(.trailing, 16)
            .accessibilityLabel("testerbypass")
        }
        .overlay(alignment: .topLeading) {
            OBBackButton(size: 34) { m.go(.plan) }
                .padding(.top, 4)
                .padding(.leading, 16)
        }
        .sheet(isPresented: $showPrivacy) { NavigationStack { PrivacyView() } }
        .task { if !sub.productsAvailable { await sub.loadProducts() } }
        .onAppear { store.track("paywall_viewed", ["context": "onboarding_v2"]) }
    }

    private var hero: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .top) {
                OBRays(opacity: 0.42, inner: 0.18, outer: 0.62, duration: 30, filled: true, diameter: 460)
                    .position(x: w / 2, y: 86)
                OBTwinkle(color: OB.lemon, size: 10, delay: 0).position(x: 83, y: 47)
                OBTwinkle(color: OB.leaf, size: 8, delay: 0.6).position(x: w - 88, y: 28)
                OBTwinkle(color: OB.orange, size: 7, delay: 1.2).position(x: w - 67, y: 139)
                ZestyMascot(mood: .happy, size: 132, seedKey: "pw")
                    .padding(.top, 19)
                    .obPop(duration: 0.6)
            }
            .frame(width: w, height: geo.size.height)
        }
        .frame(height: 190)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [Color(hex: 0xFCEFB4), OB.cream], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        }
    }

    private func planCard(id: String, name: String, price: String, unit: String, terms: String, badge: String?) -> some View {
        let on = m.a.plan == id
        return Button { m.a.plan = id } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(name.uppercased()).font(OB.font(12, 800)).tracking(0.72).foregroundStyle(on ? .white.opacity(0.72) : OB.sub)
                Text(price).font(OB.font(25, 800)).tracking(-0.75).foregroundStyle(on ? .white : OB.ink)
                    .lineLimit(1).minimumScaleFactor(0.7).padding(.top, 6)
                Text(unit).font(OB.font(11.5, 600)).foregroundStyle(on ? .white.opacity(0.72) : OB.sub).padding(.top, 2)
                Text(terms).font(OB.font(11.5, 700)).foregroundStyle(on ? OB.lemon : OB.green).padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
            .padding(.top, badge == nil ? 16 : 22)
            .padding(.bottom, 15)
            .background(on ? OB.ink : .white, in: .rect(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(on ? OB.ink : OB.inputBorder, lineWidth: 2))
            .overlay(alignment: .topLeading) {
                if let badge {
                    Text(badge).font(OB.font(10, 800)).tracking(0.4).foregroundStyle(OB.ink)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(OB.lemon, in: .capsule)
                        .fixedSize()
                        .offset(x: 14, y: -11)
                }
            }
            .shadow(color: on ? OB.ink.opacity(0.28) : .clear, radius: 13, x: 0, y: 12)
            .scaleEffect(on ? 1.02 : 0.98)
            .animation(.easeInOut(duration: 0.25), value: on)
        }
        .buttonStyle(.plain)
    }

    private func purchase() async {
        guard let product = annual ? sub.annual : sub.monthly else {
            message = "Subscriptions aren’t available right now. Please try again."
            await sub.loadProducts()
            return
        }
        purchasing = true
        message = nil
        defer { purchasing = false }
        do {
            if try await sub.purchase(product) {
                if annual, let days = trialDays { store.recordTrialStart(days: days, priceText: annualPrice) }
                store.track("subscription_started", ["plan": product.id])
                m.a.completed = true
                m.go(.done)
            }
        } catch {
            message = "The purchase didn’t go through. Please try again."
        }
    }

    private func restore() async {
        await sub.restore()
        if store.isPremium { m.go(.done) } else { message = "No active subscription found for this Apple ID." }
    }
}

struct OBTwinkle: View {
    let color: Color
    let size: CGFloat
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate - delay
            let p = (1 - cos(2 * .pi * (t.truncatingRemainder(dividingBy: 2) / 2))) / 2
            Circle().fill(color).frame(width: size, height: size).scaleEffect(0.4 + 0.6 * p).opacity(p)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Done

struct OBDoneScreen: View {
    @Environment(OnboardingModel.self) private var m
    @Environment(AppStore.self) private var store
    @State private var start = Date()
    @State private var dropped = false

    var body: some View {
        ZStack {
            OB.sun(rx: 1.0, ry: 0.6, cy: 0.42, stop: 0.62, inner: Color(hex: 0xFFF6CF))
            confetti
            VStack(spacing: 0) {
                ZestyMascot(mood: .celebrating, size: 150, seedKey: "dn")
                    .offset(y: dropped ? 0 : -320)
                    .opacity(dropped ? 1 : 0)
                Text(m.doneMode == "back" ? "Welcome back!" : "YOU’RE IN!")
                    .font(OB.font(40, 800)).tracking(-1.2).foregroundStyle(OB.ink)
                    .padding(.top, 18)
                    .obIn(delay: 0.7, duration: 0.4)
                Text("Your Lemora is ready.").font(OB.font(15, 400)).foregroundStyle(OB.muted)
                    .padding(.top, 6)
                    .obIn(delay: 0.85, duration: 0.4)
                Button { m.finish(store) } label: {
                    Text("START EXPLORING").font(OB.font(15, 800)).tracking(0.6).foregroundStyle(.white)
                        .padding(.horizontal, 30).padding(.vertical, 16)
                        .background(OB.ink, in: .capsule)
                }
                .buttonStyle(OBPress())
                .padding(.top, 28)
                .obIn(delay: 1, duration: 0.4)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 13)) { dropped = true }
        }
    }

    private var confetti: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(start)
                let colors: [Color] = [OB.lemon, OB.leaf, OB.orange, OB.ink, OB.green]
                for i in 0..<22 {
                    let dur = 2.4 + Double(i % 5) * 0.35
                    let local = t - Double(i % 7) * 0.18
                    guard local > 0, local < dur * 2 else { continue }
                    let k = local.truncatingRemainder(dividingBy: dur) / dur
                    let e = 1 - pow(1 - k, 1.6)
                    let x = size.width * CGFloat((i * 37) % 100) / 100
                    let y = -60 + (size.height + 100) * e
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .degrees(620 * e))
                    let w: CGFloat = i % 3 == 0 ? 10 : 7, h: CGFloat = i % 3 == 0 ? 10 : 11
                    let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                    c.fill(i % 3 == 0 ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 3), with: .color(colors[i % 5]))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Merge sheet

struct OBMergeSheet: View {
    @Environment(OnboardingModel.self) private var m
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack(alignment: .bottom) {
            OB.ink.opacity(0.45).ignoresSafeArea().transition(.opacity)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    ZestyMascot(mood: .curious, size: 52, seedKey: "mg")
                    OBText("Update your Lemora preferences with these new answers?", 21, 800, tracking: -0.02)
                }
                OBText("Welcome back\(store.data.account.map { ", " + ($0.name.split(separator: " ").first.map(String.init) ?? $0.name) } ?? ""). You just answered the questions again. Keep your saved profile, or replace it with today’s answers.",
                       13, 500, color: OB.muted)
                    .lineSpacing(3)
                    .padding(.top, 10)
                OBPrimaryButton(title: "Update Preferences", fontSize: 16) { m.mergeUpdate(store) }
                    .padding(.top, 16)
                Button { m.mergeKeep(store) } label: {
                    Text("Keep Existing").font(OB.font(16, 800)).foregroundStyle(OB.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(.white, in: .capsule)
                        .overlay(Capsule().strokeBorder(OB.border, lineWidth: 1.5))
                }
                .buttonStyle(OBPress())
                .padding(.top, 8)
            }
            .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 40)
            .background(OB.cream, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .transition(.move(edge: .bottom))
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
