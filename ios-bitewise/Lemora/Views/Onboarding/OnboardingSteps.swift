import SwiftUI

// MARK: - Landing

struct OBLandingScreen: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        VStack(spacing: 0) {
            LemoraWordmark(size: 26, color: OB.ink)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) { LanguageMenu() }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(OB.sunSoft).frame(width: 240, height: 240)
                    OBRays(opacity: 0.28, inner: 0.48, outer: 0.72, duration: 36, diameter: 300)
                    ZestyMascot(mood: .talking, size: 150, seedKey: "land")
                    Text("Hi, I’m Zesty!")
                        .font(OB.font(12.5, 700))
                        .foregroundStyle(OB.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16))
                        .shadow(color: OB.ink.opacity(0.1), radius: 9, x: 0, y: 6)
                        .obPop(delay: 0.35, duration: 0.5)
                        .offset(x: 105, y: -78)
                }
                .frame(width: 240, height: 240)
                .obPop()

                OBText("Meals you love, at prices you’ll love more.", 36, 800, tracking: -0.035, align: .center)
                    .lineSpacing(-4)
                    .padding(.top, 34)
                OBText("I’ll learn your taste, then match it with the best grocery deals near you.", 15, 500, color: OB.muted, align: .center)
                    .lineSpacing(3)
                    .frame(maxWidth: 290)
                    .padding(.top, 12)
            }
            Spacer(minLength: 0)
            OBPrimaryButton(title: "GET STARTED") {
                m.authCtx = .new
                m.go(.hear)
            }
            .tracking(0.34)
            OBLoginRow(size: 13.5) { m.authCtx = .existing; m.go(.signin) }
                .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(OB.sun(rx: 1.1, ry: 0.55, cy: 0.34, stop: 0.64))
    }
}

/// Spinning sun rays (CSS repeating-conic-gradient with a circular radial mask).
struct OBRays: View {
    var opacity: Double
    var inner: CGFloat
    var outer: CGFloat
    var duration: Double
    var filled: Bool = false
    var diameter: CGFloat = 300
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let angle = (tl.date.timeIntervalSinceReferenceDate / duration).truncatingRemainder(dividingBy: 1) * 360
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = size.width
                let step = 22.0 * .pi / 180, width = 8.0 * .pi / 180
                var a = -Double.pi / 2
                while a < 1.5 * .pi {
                    var p = Path()
                    p.move(to: c)
                    p.addArc(center: c, radius: r, startAngle: .radians(a), endAngle: .radians(a + width), clockwise: false)
                    p.closeSubpath()
                    ctx.fill(p, with: .color(OB.lemon.opacity(opacity)))
                    a += step
                }
            }
            .rotationEffect(.degrees(angle))
        }
        .frame(width: diameter, height: diameter)
        .mask {
            RadialGradient(stops: filled
                           ? [.init(color: .black, location: 0), .init(color: .black, location: inner), .init(color: .clear, location: outer)]
                           : [.init(color: .clear, location: 0), .init(color: .clear, location: inner),
                              .init(color: .black, location: inner + 0.04), .init(color: .clear, location: outer)],
                           center: .center, startRadius: 0, endRadius: diameter / 2 * 1.4142)
        }
        .allowsHitTesting(false)
    }
}

struct OBLoginRow: View {
    var question = "Already have an account?"
    var link = "Log in"
    var size: CGFloat = 13
    var underline = true
    let action: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text(question).font(OB.font(size, 500)).foregroundStyle(OB.muted)
            Button(action: action) {
                Text(link).font(OB.font(size, 800)).foregroundStyle(OB.ink)
                    .underline(underline)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Auth buttons (Apple / Google / Email)

struct OBAuthButtons: View {
    let apple: () -> Void
    let google: () -> Void
    let emailAction: () -> Void
    var busy = false

    var body: some View {
        VStack(spacing: 10) {
            Button(action: apple) {
                HStack(spacing: 12) {
                    OBArt.image("logo_apple").resizable().frame(width: 18, height: 21)
                    Text("Continue with Apple").font(OB.font(16, 700)).foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(.black, in: .capsule)
            }
            Button(action: google) {
                HStack(spacing: 12) {
                    OBArt.image("logo_google").resizable().frame(width: 20, height: 20)
                    Text("Continue with Google").font(OB.font(16, 700)).foregroundStyle(Color(hex: 0x1F1F1F))
                }
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(.white, in: .capsule)
                .overlay(Capsule().strokeBorder(OB.border, lineWidth: 1.5))
            }
            Button(action: emailAction) {
                HStack(spacing: 12) {
                    OBArt.image("logo_mail").resizable().frame(width: 24, height: 24)
                    Text("Continue with Email").font(OB.font(16, 700)).foregroundStyle(OB.ink)
                }
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(.white, in: .capsule)
                .overlay(Capsule().strokeBorder(OB.border, lineWidth: 1.5))
            }
        }
        .buttonStyle(OBPress())
        .disabled(busy)
        .opacity(busy ? 0.6 : 1)
    }
}

struct OBSignInScreen: View {
    @Environment(OnboardingModel.self) private var m
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                OBBackButton(size: 38) { m.go(m.authCtx == .merge ? .account : .landing) }
                Spacer()
            }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                ZestyMascot(mood: .happy, size: 110, seedKey: "si")
                OBText("Welcome back", 32, 800, tracking: -0.03, align: .center).padding(.top, 18)
                OBText(m.authCtx == .merge ? "Sign in and I’ll keep the answers you just gave me." : "Sign in to pick up where you left off.",
                       14.5, 500, color: OB.muted, align: .center)
                    .frame(maxWidth: 290)
                    .padding(.top, 8)
                if let e = m.errorText {
                    OBText(e, 12.5, 600, color: OB.red, align: .center).padding(.top, 10)
                }
            }
            Spacer(minLength: 0)
            OBAuthButtons(apple: { m.authApple(store) }, google: { m.authGoogle(store) },
                          emailAction: { m.emailMode = .signin; m.resetSent = false; m.go(.email) }, busy: m.busy)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(OB.cream.ignoresSafeArea())
    }
}

// MARK: - Question shell

struct OBStepScreen: View {
    @Environment(OnboardingModel.self) private var m

    private var meta: (title: String, sub: String, mood: ZestyMascot.Mood) {
        let hh = max(1, m.a.household)
        switch m.screen {
        case .hear: return ("How did you hear about us?", "Just so I know who to thank.", .talking)
        case .goal: return ("What are your goals?", "Pick all that apply. This shapes everything I recommend.", .idea)
        case .weightAsk: return ("", "", .idea)
        case .branch:
            return m.isBodyGoal ? ("Let’s set your numbers", "Used to size portions and protein.", .idle)
                                : ("What do you love eating?", "Pick a few. Swipes refine the rest.", .idle)
        case .people: return ("How many people do you cook for each week?", "Counting you. Everyone at the table.", .talking)
        case .diet: return ("Do you follow a specific diet?", "Pick all that apply. I’ll keep them compatible.", .talking)
        case .allergies: return ("Do you have any food allergies?", "These are strict. I’ll never show recipes with them.", .curious)
        case .dislikes: return ("Anything you’d rather not eat?", "Tap a few or search any ingredient.", .talking)
        case .meals: return ("What kind of recipes are you looking for?", "Pick the meals you want ideas for.", .idea)
        case .location: return ("Where are you shopping from?", "I use this to find stores and deals near you.", .thinking)
        case .stores: return ("Where do you shop?", "Pick every store you’d go to.", .cart)
        case .budget: return ("What’s your weekly grocery budget?", hh == 1 ? String(localized: "For your whole household. I started from 1 person.") : String(localized: "For your whole household. I started from \(hh) people."), .thinking)
        case .strategy: return ("How do you like to shop?", "I’ll plan your list around this.", .cart)
        default: return ("", "", .idle)
        }
    }

    private var reaction: String {
        let a = m.a
        switch m.screen {
        case .hear: return a.referral == "friends_family" ? "Tell them Zesty says hi!" : "Thanks! Good to know."
        case .goal: return OBCatalog.goalReaction[a.goal] ?? ""
        case .branch: return "Got it."
        case .people:
            if a.household == 1 { return String(localized: "Cooking for one, got it.") }
            return a.household >= 5 ? String(localized: "Cooking for 5+, got it.") : String(localized: "Cooking for \(a.household), got it.")
        case .diet: return m.dietNote.isEmpty ? "Got it. I’ll match every recipe to this." : m.dietNote
        case .allergies:
            if a.noAllergy { return String(localized: "Great, no restrictions to track.") }
            return a.allergies.count == 1 ? String(localized: "1 allergen excluded, always.") : String(localized: "\(a.allergies.count) allergens excluded, always.")
        case .dislikes:
            if a.dislikes.isEmpty { return String(localized: "Okay, anything goes.") }
            return a.dislikes.count == 1 ? String(localized: "Noted. I’ll keep 1 food off your plate.") : String(localized: "Noted. I’ll keep \(a.dislikes.count) foods off your plate.")
        case .meals:
            if (a.meals ?? []).isEmpty { return String(localized: "Everything it is, breakfast to dessert.") }
            return String(localized: "Got it. I’ll focus on \(AppFormat.list(m.mealList).lowercased()).")
        case .stores: return a.stores.count == 1 ? String(localized: "1 store selected.") : String(localized: "\(a.stores.count) stores selected.")
        case .budget: return a.noBudget ? "Fine by me. I’ll still find the best value." : "Nice. I’ll work with that."
        case .strategy: return OBCatalog.strategyReaction[a.strategy] ?? ""
        default: return ""
        }
    }

    private var mood: ZestyMascot.Mood {
        if m.nudgeUntil > Date() { return .impatient }
        let aNo = m.screen == .allergies && !m.aQuery.trimmingCharacters(in: .whitespaces).isEmpty && OBData.search(OBData.allergens, m.aQuery).isEmpty
        let iNo = m.screen == .dislikes && !m.iQuery.trimmingCharacters(in: .whitespaces).isEmpty && OBData.search(OBData.ingredients, m.iQuery).isEmpty
        if aNo || iNo { return .dizzy }
        if m.reacted {
            return m.screen == .branch && ["eat_healthier", "discover_meals"].contains(m.a.goal) ? .love : .happy
        }
        return meta.mood
    }

    var body: some View {
        let idx = m.stepIndex ?? 0
        let nudging = m.nudgeUntil > Date()
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                OBBackButton { m.back() }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(OB.track)
                        Capsule().fill(OB.lemon)
                            .frame(width: geo.size.width * CGFloat(idx + 1) / CGFloat(max(1, m.flow.count)))
                            .animation(.timingCurve(0.3, 0.7, 0.3, 1, duration: 0.45), value: idx)
                    }
                }
                .frame(height: 7)
                Button("Skip") { m.skip() }
                    .font(OB.font(13, 700))
                    .foregroundStyle(OB.faint)
                    .buttonStyle(.plain)
                    .opacity([.location, .stores].contains(m.screen) ? 0 : 1)
                    .disabled([.location, .stores].contains(m.screen))
            }

            if m.screen != .weightAsk {
            HStack(alignment: .bottom, spacing: 10) {
                ZestyMascot(mood: mood, size: 64, seedKey: "z\(m.screen.rawValue)")
                    .id("z\(m.screen.rawValue)\(m.bump)\(nudging ? "n" : "")\(mood.rawValue)")
                VStack(alignment: .leading, spacing: 4) {
                    OBText(meta.title, 21, 800, tracking: -0.02)
                    OBText(meta.sub, 12.5, 500, color: OB.sub)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 6, bottomTrailingRadius: 22, topTrailingRadius: 22))
                .shadow(color: OB.ink.opacity(0.06), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 26)

            Text(nudging ? "Pick one first, I’m waiting!" : reaction)
                .font(OB.font(12.5, 700))
                .foregroundStyle(!m.dietNote.isEmpty && m.screen == .diet ? Color(hex: 0x8A5A00) : OB.green)
                .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
                .padding(.leading, 76)
                .padding(.top, 10)
                .opacity((m.reacted || nudging) ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: m.reacted)
            }

            ScrollView {
                stepBody
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                    .id(m.screen)
                    .obIn()
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .padding(.horizontal, -6)
            .padding(.top, 16)

            Button { m.next() } label: {
                Text(m.screen == .strategy ? "CONTINUE" : "Continue")
                    .font(OB.font(17, 800))
                    .foregroundStyle(m.canContinue ? OB.ink : OB.disabledText)
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background(m.canContinue ? OB.lemon : OB.track, in: .capsule)
                    .shadow(color: m.canContinue ? OB.lemon.opacity(0.4) : .clear, radius: 8, x: 0, y: 6)
            }
            .buttonStyle(OBPress())
            .padding(.top, 16)
            .animation(.easeInOut(duration: 0.2), value: m.canContinue)

            if m.screen == .hear {
                OBLoginRow { m.authCtx = .existing; m.go(.signin) }.padding(.top, 10)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(OB.cream.ignoresSafeArea())
    }

    @ViewBuilder private var stepBody: some View {
        switch m.screen {
        case .hear: OBHearStep()
        case .goal: OBGoalStep()
        case .weightAsk: OBWeightAskStep()
        case .branch: if m.isBodyGoal { OBBodyStep() } else { OBTasteStep() }
        case .people: OBPeopleStep()
        case .diet: OBDietStep()
        case .allergies: OBAllergyStep()
        case .dislikes: OBDislikeStep()
        case .meals: OBMealStep()
        case .location: OBLocationStep()
        case .stores: OBStoresStep()
        case .budget: OBBudgetStep()
        case .strategy: OBStrategyStep()
        default: EmptyView()
        }
    }
}

private let twoCols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

// MARK: - Steps

struct OBHearStep: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(OBCatalog.hear) { o in
                let on = m.a.referral == o.id
                Button { m.setReferral(o.id) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        hearIcon(o)
                        Text(o.label)
                            .font(OB.font(14, 700)).foregroundStyle(OB.ink)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .frame(height: 34, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .obCard(on)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private func hearIcon(_ o: OBCatalog.Option) -> some View {
        if let logo = OBCatalog.hearLogo(o.id) {
            OBArt.image(logo).resizable().frame(width: 40, height: 40)
        } else if o.id == "friends_family" {
            Text("👋").font(.system(size: 20)).frame(width: 40, height: 40).background(OB.sunSoft, in: .rect(cornerRadius: 12))
        } else {
            Text("…").font(OB.font(18, 800)).foregroundStyle(OB.ink).frame(width: 40, height: 40).background(OB.pill, in: .rect(cornerRadius: 12))
        }
    }
}

struct OBGoalStep: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        VStack(spacing: 8) {
            ForEach(OBCatalog.goals) { g in
                let on = m.selectedGoals.contains(g.id)
                Button { m.setGoal(g.id) } label: {
                    HStack(spacing: 14) {
                        Text(g.icon).font(.system(size: 18)).frame(width: 40, height: 40).background(Color(hex: g.iconBg), in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.label).font(OB.font(15, 700)).foregroundStyle(OB.ink)
                            Text(g.sub).font(OB.font(12, 400)).foregroundStyle(OB.sub)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        OBCheck(on: on)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .obCard(on)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// "Do you have a target weight?" before the weight page. "No" skips the weight page.
struct OBWeightAskStep: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        let yes = m.a.hasTargetWeight ?? true
        VStack(spacing: 0) {
            ZestyMascot(mood: m.reacted ? .happy : .idea, size: 118, seedKey: "zweightAsk")
                .id("zweightAsk\(m.bump)")
                .frame(width: 150, height: 150)
                .background(OB.sunSoft, in: .circle)
                .padding(.top, 8)
            OBText(lemoraText("Do you have a target weight?", fr: "As-tu un poids visé ?", es: "¿Tienes un peso objetivo?"),
                   28, 800, tracking: -0.02, align: .center)
                .padding(.top, 26)
            OBText(lemoraText("It helps us size your portions. You can change it later.",
                              fr: "Ça nous aide à ajuster tes portions. Tu peux le changer plus tard.",
                              es: "Nos ayuda a ajustar tus porciones. Puedes cambiarlo después."),
                   15, 500, color: OB.sub, align: .center)
                .padding(.top, 8)
                .padding(.horizontal, 12)
            VStack(spacing: 12) {
                option("🎯", fill: OB.sunSoft,
                       title: lemoraText("Yes, I have one", fr: "Oui, j’en ai un", es: "Sí, tengo uno"),
                       sub: lemoraText("We’ll ask for the number next", fr: "On te demande le chiffre ensuite", es: "Te pedimos la cifra después"),
                       on: yes) { m.setHasTargetWeight(true) }
                option("👌", fill: OB.mint,
                       title: lemoraText("No target weight", fr: "Non, pas de poids visé", es: "No, sin peso objetivo"),
                       sub: lemoraText("We’ll move on", fr: "On passe à la suite", es: "Pasamos a lo siguiente"),
                       on: !yes) { m.setHasTargetWeight(false) }
            }
            .padding(.top, 30)
        }
        .frame(maxWidth: .infinity)
    }

    private func option(_ icon: String, fill: Color, title: String, sub: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(icon).font(.system(size: 20))
                    .frame(width: 52, height: 52)
                    .background(fill, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).font(OB.font(16, 800)).foregroundStyle(OB.ink)
                    Text(verbatim: sub).font(OB.font(13, 400)).foregroundStyle(OB.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                OBRadio(on: on)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .obCard(on)
        }
        .buttonStyle(.plain)
    }
}

struct OBBodyStep: View {
    @Environment(OnboardingModel.self) private var m

    private func shown(_ lb: Int) -> String {
        m.a.unit == "lb" ? String(lb) : String(format: "%.1f", Double(lb) * 0.4536)
    }

    var body: some View {
        @Bindable var m = m
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                weightCard("Current", shown(m.a.current), fill: .white, labelColor: OB.faint)
                weightCard("Target", shown(m.a.target), fill: OB.sunSoft, labelColor: Color(hex: 0x7A6512))
            }
            sliderRow("Current weight", value: $m.a.current, tint: OB.ink)
            sliderRow("Target weight", value: $m.a.target, tint: OB.green)
            HStack {
                Text("Units").font(OB.font(14, 700)).foregroundStyle(OB.ink)
                Spacer()
                HStack(spacing: 3) {
                    ForEach(["lb", "kg"], id: \.self) { u in
                        Button { m.a.unit = u } label: {
                            Text(u).font(OB.font(13, 700))
                                .foregroundStyle(m.a.unit == u ? .white : OB.muted)
                                .padding(.horizontal, 16).padding(.vertical, 6)
                                .background(m.a.unit == u ? OB.ink : .clear, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(OB.pill, in: .capsule)
            }
            OBText("Targets stay within general wellness guidance. This isn’t medical advice.", 11.5, 400, color: OB.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func weightCard(_ title: String, _ value: String, fill: Color, labelColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(OB.font(11, 700)).tracking(0.66).foregroundStyle(labelColor)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(OB.font(28, 800)).foregroundStyle(OB.ink).monospacedDigit()
                Text(m.a.unit).font(OB.font(13, 400)).foregroundStyle(OB.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(fill, in: .rect(cornerRadius: 20))
        .shadow(color: fill == .white ? OB.ink.opacity(0.05) : .clear, radius: 5, x: 0, y: 2)
    }

    private func sliderRow(_ label: String, value: Binding<Int>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(OB.font(12, 700)).foregroundStyle(OB.sub)
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: 90...330, step: 1)
                .tint(tint)
        }
    }
}

struct OBTasteStep: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        VStack(spacing: 8) {
            Button { m.toggleAllCuisines() } label: {
                HStack(spacing: 10) {
                    iconBox("🌍", on: m.a.cuisines.contains("all"))
                    Text("I love it all").font(OB.font(14, 800)).foregroundStyle(OB.ink)
                    Spacer()
                }
                .obTile(m.a.cuisines.contains("all"))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
            LazyVGrid(columns: twoCols, spacing: 8) {
                ForEach(OBCatalog.cuisines, id: \.id) { c in
                    let on = m.a.cuisines.contains(c.id)
                    Button { m.toggleCuisine(c.id) } label: {
                        OBTileRow(icon: c.icon, label: c.label, on: on)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

func iconBox(_ icon: String, on: Bool, red: Bool = false) -> some View {
    Text(icon)
        .font(.system(size: 18))
        .frame(width: 34, height: 34)
        .background(on ? .white : (red ? OB.redIcon : OB.tileIcon), in: .rect(cornerRadius: 11))
}

struct OBTileRow: View {
    let icon: String
    let label: String
    let on: Bool
    var red: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            iconBox(icon, on: on, red: red)
            Text(label)
                .font(OB.font(14, 700))
                .foregroundStyle(on && red ? OB.redText : OB.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            OBCheck(on: on, size: 20, red: red)
        }
        .obTile(on, red: red)
    }
}

struct OBPeopleStep: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                ForEach(1...5, id: \.self) { n in
                    let on = m.a.household == n
                    Button { m.setHousehold(n) } label: {
                        VStack(spacing: 2) {
                            Text(n == 5 ? "5+" : String(n)).font(OB.font(22, 800))
                            Text(n == 1 ? "just me" : "people").font(OB.font(10.5, 600)).opacity(0.7)
                        }
                        .foregroundStyle(on ? .white : OB.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(on ? OB.ink : .white, in: .rect(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(on ? OB.ink : .clear, lineWidth: 1.5))
                        .shadow(color: on ? .clear : OB.ink.opacity(0.05), radius: 4, x: 0, y: 2)
                        .scaleEffect(on ? 1.04 : 1)
                        .animation(.easeInOut(duration: 0.2), value: on)
                    }
                    .buttonStyle(.plain)
                }
            }
            OBInfoBox(icon: "🍽️", text: "I’ll size every recipe, your grocery list and your budget for this many people.")
        }
    }
}

struct OBInfoBox: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text(icon).font(.system(size: 15))
            Text(text).font(OB.font(12, 400)).foregroundStyle(OB.mintText).lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(OB.mint, in: .rect(cornerRadius: 16))
    }
}

struct OBDietStep: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        VStack(spacing: 9) {
            let noneOn = m.a.diets.contains("none")
            Button { m.pickDiet("none") } label: {
                HStack(spacing: 14) {
                    Text("🍽️").font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Specific Diet").font(OB.font(15, 800)).foregroundStyle(OB.ink)
                        Text("I eat a bit of everything").font(OB.font(12, 500)).foregroundStyle(OB.sub)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    OBCheck(on: noneOn)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .obCard(noneOn)
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: twoCols, spacing: 8) {
                ForEach(OBCatalog.diets) { d in
                    let on = m.a.diets.contains(d.id)
                    Button { m.pickDiet(d.id) } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top) {
                                Text(d.icon).font(.system(size: 20))
                                Spacer()
                                OBCheck(on: on)
                            }
                            Text(d.label).font(OB.font(13.5, 800)).foregroundStyle(OB.ink).padding(.top, 8)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Text(d.sub).font(OB.font(11, 500)).foregroundStyle(OB.sub).padding(.top, 2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .obCard(on, radius: 20)
                        .scaleEffect(on ? 1.005 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct OBMealStep: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        let picked = m.a.meals ?? []
        VStack(spacing: 9) {
            let allOn = picked.isEmpty
            Button { m.allMeals() } label: {
                HStack(spacing: 14) {
                    Text("🍽️").font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Meals").font(OB.font(15, 800)).foregroundStyle(OB.ink)
                        Text("Show me every kind of recipe").font(OB.font(12, 500)).foregroundStyle(OB.sub)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    OBCheck(on: allOn)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .obCard(allOn)
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: twoCols, spacing: 8) {
                ForEach(OBCatalog.meals) { d in
                    let on = picked.contains(d.id)
                    Button { m.toggleMeal(d.id) } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top) {
                                Text(d.icon).font(.system(size: 20))
                                Spacer()
                                OBCheck(on: on)
                            }
                            Text(d.label).font(OB.font(13.5, 800)).foregroundStyle(OB.ink).padding(.top, 8)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Text(d.sub).font(OB.font(11, 500)).foregroundStyle(OB.sub).padding(.top, 2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .obCard(on, radius: 20)
                        .scaleEffect(on ? 1.005 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct OBSearchField: View {
    let placeholder: String
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("⌕").font(.system(size: 15)).foregroundStyle(OB.faint)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(OB.faint))
                .font(OB.font(14, 600))
                .foregroundStyle(OB.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .padding(.vertical, 10)
        }
        .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 4)
        .background(.white, in: .capsule)
        .overlay(Capsule().strokeBorder(OB.inputBorder, lineWidth: 1.5))
        .shadow(color: OB.ink.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}

struct OBSearchResults: View {
    let results: [OBSearchResult]
    let added: (String) -> Bool
    var actionColor: Color = OB.ink
    let pick: (OBSearchResult) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(results.enumerated()), id: \.element.id) { i, r in
                Button { pick(r) } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: r.display).font(OB.font(14, 700)).foregroundStyle(OB.ink)
                            if let via = r.via {
                                Text("matches “\(via)”")
                                    .font(OB.font(11, 500)).foregroundStyle(OB.faint).lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(added(r.id) ? "Added" : "+ Add").font(OB.font(12, 800)).foregroundStyle(actionColor)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(.white)
                    .overlay(alignment: .top) { if i > 0 { Rectangle().fill(OB.divider).frame(height: 1) } }
                }
                .buttonStyle(.plain)
            }
        }
        .background(.white, in: .rect(cornerRadius: 18))
        .clipShape(.rect(cornerRadius: 18))
        .shadow(color: OB.ink.opacity(0.12), radius: 13, x: 0, y: 10)
        .padding(.top, 6)
        .transition(.opacity)
    }
}

struct OBAllergyStep: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        @Bindable var m = m
        let quick = OBCatalog.quickAllergy + m.a.allergies.filter { !OBCatalog.quickAllergy.contains($0) }
        let results = m.aQuery.trimmingCharacters(in: .whitespaces).isEmpty ? [] : OBData.search(OBData.allergens, m.aQuery)
        VStack(spacing: 12) {
            Button { m.toggleNoAllergy() } label: {
                HStack(spacing: 14) {
                    Text("🙌").font(.system(size: 20))
                    Text("NO ALLERGIES").font(OB.font(15, 800)).foregroundStyle(OB.ink).frame(maxWidth: .infinity, alignment: .leading)
                    OBCheck(on: m.a.noAllergy)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .obCard(m.a.noAllergy)
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: twoCols, spacing: 8) {
                ForEach(quick, id: \.self) { id in
                    Button { m.toggleAllergy(id) } label: {
                        OBTileRow(icon: OBCatalog.allergyIcon[id] ?? "⚠️", label: m.allergenName(id), on: m.a.allergies.contains(id), red: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                OBSearchField(placeholder: "Search allergies", text: $m.aQuery) {
                    if let first = results.first { m.addAllergy(first.id) }
                }
                if !results.isEmpty {
                    OBSearchResults(results: results, added: { m.a.allergies.contains($0) }, actionColor: OB.red) { m.addAllergy($0.id) }
                } else if !m.aQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    OBText("No match in our allergen list. Try another spelling.", 12, 500, color: OB.faint)
                        .padding(.horizontal, 6).padding(.top, 8)
                }
            }

            HStack(alignment: .top, spacing: 9) {
                Text("!").font(OB.font(12, 800)).foregroundStyle(.white).frame(width: 22, height: 22).background(OB.red, in: .circle)
                OBText("Strict safety filter. Lemora never recommends a recipe containing these. Always check product labels.", 12, 600, color: OB.redText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(OB.redSoft, in: .rect(cornerRadius: 16))
        }
    }
}

struct OBDislikeStep: View {
    @Environment(OnboardingModel.self) private var m

    private func displayName(_ d: OnboardingAnswers.Dislike) -> String {
        guard let item = OBData.ingredients.first(where: { $0.id == d.id }) else { return lemoraLocalized(d.name) }
        return OBData.displayName(en: item.en, fr: item.fr)
    }

    var body: some View {
        @Bindable var m = m
        let results = m.iQuery.trimmingCharacters(in: .whitespaces).isEmpty ? [] : OBData.search(OBData.ingredients, m.iQuery)
        let custom = m.a.dislikes.filter { d in !OBCatalog.quickDislike.contains { $0.id == d.id } }
        VStack(spacing: 12) {
            LazyVGrid(columns: twoCols, spacing: 8) {
                ForEach(OBCatalog.quickDislike, id: \.id) { q in
                    let item = OBData.ingredients.first { $0.id == q.id }
                    let name = item?.en ?? q.id
                    let on = m.a.dislikes.contains { $0.id == q.id }
                    Button { m.toggleDislike(id: q.id, name: name) } label: {
                        OBTileRow(icon: q.icon, label: item.map { OBData.displayName(en: $0.en, fr: $0.fr) } ?? name, on: on)
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                OBSearchField(placeholder: "Search an ingredient", text: $m.iQuery) {
                    if let first = results.first { m.addDislike(first) }
                }
                if !results.isEmpty {
                    OBSearchResults(results: results, added: { id in m.a.dislikes.contains { $0.id == id } }) { m.addDislike($0) }
                } else if !m.iQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    OBText("No ingredient found. Try another spelling.", 12, 500, color: OB.faint)
                        .padding(.horizontal, 6).padding(.top, 8)
                }
            }
            if !custom.isEmpty {
                OBFlow(spacing: 6) {
                    ForEach(custom, id: \.id) { d in
                        Button { m.toggleDislike(id: d.id, name: d.name) } label: {
                            HStack(spacing: 6) {
                                Text(verbatim: displayName(d))
                                Text(verbatim: "✕").opacity(0.6)
                            }
                            .font(OB.font(12.5, 700)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(OB.ink, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            OBInfoBox(icon: "🌱", text: "Taste only, separate from allergies. I’ll also learn from your swipes.")
        }
    }
}

/// Simple wrapping layout for chips.
struct OBFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += size.width + spacing
            rowH = max(rowH, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxW), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}

struct OBLocationStep: View {
    @Environment(OnboardingModel.self) private var m
    /// The postal code field only opens after "Enter manually" (or when location fails).
    @State private var showManual = false

    var body: some View {
        @Bindable var m = m
        let loc = m.currentLocation
        VStack(spacing: 12) {
            GeometryReader { geo in
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.55)
                let far = sqrt(pow(geo.size.width / 2, 2) + pow(geo.size.height * 0.55, 2))
                ZStack {
                    RadialGradient(stops: [.init(color: OB.sunSoft, location: 0), .init(color: OB.sunSoft, location: 0.18),
                                           .init(color: OB.mint, location: 0.19), .init(color: OB.mint, location: 0.40),
                                           .init(color: Color(hex: 0xF3EBDA), location: 0.41), .init(color: Color(hex: 0xF3EBDA), location: 1)],
                                   center: UnitPoint(x: 0.5, y: 0.55), startRadius: 0, endRadius: far)
                    Circle().fill(OB.ink.opacity(0.12)).frame(width: 38, height: 38).position(c)
                    Circle().fill(OB.ink).frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 4)).position(c)
                    cartChip.position(x: geo.size.width * 0.22 + 16, y: geo.size.height * 0.30 + 10)
                    cartChip.position(x: geo.size.width * 0.80 - 16, y: geo.size.height * 0.24 + 10)
                    cartChip.position(x: geo.size.width * 0.72 - 16, y: geo.size.height * 0.84 - 10)
                }
            }
            .frame(height: 150)
            .clipShape(.rect(cornerRadius: 24))

            if let loc {
                HStack(spacing: 10) {
                    Text("✓").font(OB.font(12, 800)).foregroundStyle(.white).frame(width: 26, height: 26).background(OB.green, in: .circle)
                    Text("\(loc.postal) · \(m.placeName(loc))").font(OB.font(14, 700)).foregroundStyle(OB.ink).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(OB.mint, in: .rect(cornerRadius: 18))
                .obPop(duration: 0.35)
            }

            Button { showManual = false; m.allowLocation() } label: {
                HStack(spacing: 6) {
                    if m.locating { ProgressView().tint(.white) }
                    Text("📍 ALLOW LOCATION").font(OB.font(15, 800)).tracking(0.45)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(OB.ink, in: .capsule)
                .overlay(Capsule().strokeBorder(m.a.locMode == "auto" ? OB.lemon : .clear, lineWidth: 3).padding(-3))
            }
            .buttonStyle(OBPress())

            Button { m.a.locMode = "manual"; withAnimation(.snappy) { showManual = true } } label: {
                Text("ENTER MANUALLY").font(OB.font(15, 800)).tracking(0.45).foregroundStyle(OB.ink)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(.white, in: .capsule)
                    .overlay(Capsule().strokeBorder(m.a.locMode == "manual" ? OB.ink : OB.border, lineWidth: 1.5))
            }
            .buttonStyle(OBPress())

            if showManual {
                VStack(spacing: 9) {
                    HStack(spacing: 3) {
                        ForEach([("CA", "🇨🇦 " + String(localized: "Canada")), ("US", "🇺🇸 " + String(localized: "USA")), ("AU", "🇦🇺 " + String(localized: "Australia"))], id: \.0) { c in
                            Button { m.setCountry(c.0) } label: {
                                Text(c.1).font(OB.font(13, 700)).lineLimit(1).minimumScaleFactor(0.75)
                                    .foregroundStyle(m.a.country == c.0 ? .white : OB.muted)
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .background(m.a.country == c.0 ? OB.ink : .clear, in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(OB.pill, in: .capsule)

                    TextField("", text: Binding(get: { m.a.postal }, set: { m.setPostal($0) }),
                              prompt: Text(m.a.country == "CA" ? "Postal code (e.g. H2T 1P5)" : m.a.country == "AU" ? "Postcode (e.g. 2000)" : "ZIP code (e.g. 78701)").foregroundStyle(OB.faint))
                        .textContentType(.postalCode)
                        .font(OB.font(15, 700))
                        .tracking(0.6)
                        .foregroundStyle(OB.ink)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .overlay(Capsule().strokeBorder(OB.inputBorder, lineWidth: 1.5))

                    Text(loc.map { "✓ " + m.placeName($0) } ?? (m.a.postal.isEmpty ? (m.a.country == "CA" ? "Format: A1A 1A1" : m.a.country == "AU" ? "4-digit postcode" : "5-digit ZIP")
                        : m.a.postal.filter { !$0.isWhitespace }.count >= (m.a.country == "CA" ? 6 : m.a.country == "AU" ? 4 : 5)
                            ? (m.a.country == "CA" ? "Check the format: letter, number, letter, number, letter, number (A1A 1A1)" : m.a.country == "AU" ? "A postcode has 4 digits" : "A ZIP code has 5 digits")
                            : "Keep typing…"))
                        .font(OB.font(12, 700))
                        .foregroundStyle(loc != nil ? OB.green : OB.faint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                }
                .padding(14)
                .background(.white, in: .rect(cornerRadius: 20))
                .shadow(color: OB.ink.opacity(0.05), radius: 5, x: 0, y: 2)
                .obIn(duration: 0.3)
            }
        }
        .task(id: loc?.postal) { await m.lookupCity() }
        .onChange(of: m.a.locMode) { _, mode in
            if mode == "manual" { withAnimation(.snappy) { showManual = true } }
        }
    }

    private var cartChip: some View {
        Text("🛒").font(OB.font(10, 800))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(.white, in: .capsule)
            .shadow(color: OB.ink.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct OBStoresStep: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        let loc = m.currentLocation
        let nearby = m.nearbyStores
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill").font(.system(size: 14)).foregroundStyle(OB.green)
                Text(loc.map { "\($0.postal) · \(m.placeName($0))" } ?? "No location yet").font(OB.font(12.5, 700)).foregroundStyle(OB.ink)
                if m.nearbyLoading { ProgressView().controlSize(.mini) }
                Spacer()
                Button("Change") { m.go(.location) }.font(OB.font(12.5, 700)).foregroundStyle(OB.green).buttonStyle(.plain)
            }
            if !nearby.isEmpty {
                nearbyList(nearby, loc: loc)
            } else {
                staticList(loc)
            }
        }
        .task(id: loc?.postal) { await m.loadNearbyStores() }
    }

    /// Stores whose flyers are distributed at this postal code / ZIP, covered banners first.
    @ViewBuilder private func nearbyList(_ stores: [OnboardingModel.NearbyStore], loc: OnboardingModel.ResolvedLocation?) -> some View {
        let covered = stores.filter(\.covered)
        let others = stores.filter { !$0.covered }
        let shown = m.moreOpen || covered.isEmpty ? others : Array(others.prefix(6))
        if !covered.isEmpty {
            sectionTitle("Lemora finds the deals here", "Weekly flyers checked for you")
            LazyVGrid(columns: twoCols, spacing: 8) {
                ForEach(Array(covered.enumerated()), id: \.element.id) { i, store in
                    storeCard(store.name, fallback: OBCatalog.tints[i % OBCatalog.tints.count], logo: store.logo, tag: "Deals")
                }
            }
        }
        if !others.isEmpty {
            sectionTitle(covered.isEmpty ? "Grocery stores near you" : "Other stores near you",
                         covered.isEmpty ? "Pick the ones you shop at" : "Saved as your stores. Deals coming soon")
                .padding(.top, covered.isEmpty ? 0 : 6)
            LazyVGrid(columns: twoCols, spacing: 8) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, store in
                    storeCard(store.name, fallback: OBCatalog.moreTints[i % OBCatalog.moreTints.count], logo: store.logo, tag: nil)
                }
            }
            if !covered.isEmpty && others.count > 6 {
                Button { withAnimation(.easeInOut(duration: 0.25)) { m.moreOpen.toggle() } } label: {
                    Text(m.moreOpen ? "Show less" : "Show all \(others.count) stores")
                        .font(OB.font(13, 800)).foregroundStyle(OB.green)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        Text(loc.map { String(localized: "Stores with weekly flyers near \($0.postal).") } ?? String(localized: "Stores with weekly flyers near you."))
            .font(OB.font(11.5, 500)).foregroundStyle(OB.faint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(OB.font(14.5, 800)).foregroundStyle(OB.ink)
            Text(sub).font(OB.font(12, 500)).foregroundStyle(OB.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Offline fallback: the curated list for the region.
    @ViewBuilder private func staticList(_ loc: OnboardingModel.ResolvedLocation?) -> some View {
        let chains = loc?.chains ?? []
        let more = loc.flatMap { OBData.storesMore[m.a.country]?[$0.key] }?.filter { !chains.contains($0) } ?? []
        let picked = more.filter { m.isStorePicked($0) }.count
        let open = m.moreOpen || picked > 0
        LazyVGrid(columns: twoCols, spacing: 8) {
            ForEach(Array(chains.enumerated()), id: \.element) { i, name in
                storeCard(name, fallback: OBCatalog.tints[i % OBCatalog.tints.count], logo: nil, tag: nil)
            }
        }
        Button { withAnimation(.easeInOut(duration: 0.25)) { m.moreOpen = !open } } label: {
            HStack(spacing: 12) {
                Image(systemName: "basket.fill").font(.system(size: 15)).foregroundStyle(OB.green)
                    .frame(width: 34, height: 34).background(OB.mint, in: .rect(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Other stores").font(OB.font(14.5, 800)).foregroundStyle(OB.ink)
                    Text(picked > 0 ? "\(picked) selected · local and specialty grocers" : "Local, independent and specialty grocers")
                        .font(OB.font(12, 500)).foregroundStyle(OB.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down").font(.system(size: 13, weight: .heavy)).foregroundStyle(OB.sub)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(.white, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(OB.border, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        if open {
            LazyVGrid(columns: twoCols, spacing: 8) {
                ForEach(Array(more.enumerated()), id: \.element) { i, name in
                    storeCard(name, fallback: OBCatalog.moreTints[i % OBCatalog.moreTints.count], logo: nil, tag: nil)
                }
            }
            .obIn(duration: 0.3)
        }
        Text(loc.map { String(localized: "Stores shown are the ones available in \(lemoraLocalized($0.name)).") } ?? String(localized: "Stores shown are the ones available in your area."))
            .font(OB.font(11.5, 500)).foregroundStyle(OB.faint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func storeCard(_ name: String, fallback: UInt32, logo: String?, tag: String?) -> some View {
        let on = m.isStorePicked(name)
        let b = OBData.brand[name]
        let tint = Color(hex: b?.0 ?? fallback)
        let fg = Color(hex: b?.1 ?? 0xFFFFFF)
        return Button { m.toggleStore(name) } label: {
            HStack(spacing: 9) {
                ZStack {
                    Circle().fill(tint)
                    Text(OBCatalog.initials(name))
                        .font(OB.font(11, 800)).foregroundStyle(fg)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if let logo, let url = URL(string: logo) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFit().padding(4)
                                    .frame(width: 34, height: 34).background(.white, in: .circle)
                            }
                        }
                    }
                }
                .frame(width: 34, height: 34)
                .clipShape(.circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(OB.font(13.5, 700)).foregroundStyle(OB.ink)
                        .lineLimit(2).minimumScaleFactor(0.85)
                    if let tag {
                        Text(tag).font(OB.font(10, 800)).foregroundStyle(OB.green)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(OB.mint, in: .capsule)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                OBCheck(on: on)
            }
            .padding(10)
            .obCard(on)
        }
        .buttonStyle(.plain)
    }
}

struct OBBudgetStep: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        let hh = max(1, m.a.household)
        let lo = Int((Double(hh) * 50 / 5).rounded()) * 5, hi = Int((Double(hh) * 85 / 5).rounded()) * 5
        let people = hh >= 5 ? String(localized: "5+ people") : (hh == 1 ? String(localized: "1 person") : String(localized: "\(hh) people"))
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                Text("PER WEEK · \(m.currency)").font(OB.font(12, 700)).tracking(0.72).foregroundStyle(OB.sub)
                HStack(spacing: 10) {
                    roundButton("−") { m.setBudget(m.a.budget - 5); m.react() }
                    Spacer()
                    Text(OnboardingModel.money(Double(m.a.budget)))
                        .font(OB.font(54, 800)).tracking(-2.16).foregroundStyle(OB.ink).monospacedDigit()
                        .contentTransition(.numericText())
                    Spacer()
                    roundButton("+") { m.setBudget(m.a.budget + 5); m.react() }
                }
                .padding(.top, 10)
                Slider(value: Binding(get: { Double(m.a.budget) }, set: { m.setBudget(Int($0)) }), in: 30...1000, step: 5,
                       onEditingChanged: { editing in if !editing { m.react() } })
                    .tint(OB.green)
                    .padding(.top, 14)
                HStack {
                    Text(verbatim: OnboardingModel.money(30)); Spacer(); Text(verbatim: OnboardingModel.money(1000))
                }
                .font(OB.font(11, 400)).foregroundStyle(OB.faint)
                Text("Typical for \(people): \(OnboardingModel.money(Double(lo)))–\(OnboardingModel.money(Double(hi))) / week")
                    .font(OB.font(12, 600)).foregroundStyle(OB.muted)
                    .padding(.top, 10)
            }
            .padding(18)
            .background(.white, in: .rect(cornerRadius: 26))
            .shadow(color: OB.ink.opacity(0.06), radius: 8, x: 0, y: 4)
            .opacity(m.a.noBudget ? 0.4 : 1)
            .animation(.easeInOut(duration: 0.2), value: m.a.noBudget)

            Button { m.toggleNoBudget() } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Strict Budget").font(OB.font(14.5, 800))
                        Text("I’ll still show you the best value.").font(OB.font(12, 500)).opacity(0.75)
                    }
                    .foregroundStyle(OB.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    OBCheck(on: m.a.noBudget)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .obCard(m.a.noBudget)
            }
            .buttonStyle(.plain)
        }
    }

    private func roundButton(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(OB.font(22, 800)).foregroundStyle(OB.ink).frame(width: 46, height: 46).background(OB.pill, in: .circle)
        }
        .buttonStyle(OBPress())
    }
}

struct OBStrategyStep: View {
    @Environment(OnboardingModel.self) private var m

    var body: some View {
        VStack(spacing: 10) {
            ForEach(OBCatalog.strategies) { s in
                let on = m.a.strategy == s.id
                Button { m.setStrategy(s.id) } label: {
                    HStack(spacing: 14) {
                        Text(s.icon).font(.system(size: 20)).frame(width: 46, height: 46).background(Color(hex: s.bg), in: .circle)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.label).font(OB.font(15.5, 800)).tracking(0.31).foregroundStyle(OB.ink)
                            Text(s.sub).font(OB.font(12.5, 500)).foregroundStyle(OB.sub).lineSpacing(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        OBRadio(on: on)
                    }
                    .padding(14)
                    .obCard(on)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
