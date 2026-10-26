import SwiftUI
import StoreKit

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var path: NavigationPath = NavigationPath()
    @State private var confirmDelete: Bool = false

    private var profile: UserProfile { store.data.profile }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    statGrid
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                }

                Section {
                    NavigationLink { PantryView() } label: {
                        row("takeoutbag.and.cup.and.straw", String(localized: "My pantry"), String(localized: "\(store.data.pantry.count) items"))
                    }
                    NavigationLink { GoalEditView() } label: {
                        row("target", String(localized: "Goals & diet"), profile.allGoals.map(\.title).joined(separator: ", "))
                    }
                    NavigationLink { StoresEditView() } label: {
                        row("cart", String(localized: "My stores"), String(localized: "\(store.myStoreIds.count) stores"))
                    }
                }

                Section("Subscription") {
                    SubscriptionSummary()
                }

                Section("My Lemora") {
                    NavigationLink { GoalEditView() } label: { row("target", profile.allGoals.count > 1 ? String(localized: "My Goals") : String(localized: "My Goal"), profile.allGoals.map(\.title).joined(separator: ", ")) }
                    NavigationLink { DietEditView() } label: { row("leaf", String(localized: "Diet"), profile.diets.map(\.title).sorted().joined(separator: ", ")) }
                    NavigationLink { AllergyEditView() } label: { row("allergens", String(localized: "Allergies"), allergyText) }
                    NavigationLink { DislikeEditView() } label: { row("hand.thumbsdown", String(localized: "Foods I Dislike"), profile.dislikeNames.isEmpty ? String(localized: "None") : profile.dislikeNames.joined(separator: ", ")) }
                    NavigationLink { MealTypeEditView() } label: { row("fork.knife", String(localized: "Meal Types"), mealTypeText) }
                    NavigationLink { CuisineEditView() } label: { row("globe.americas", String(localized: "Cuisines"), profile.cuisines.isEmpty ? String(localized: "Any") : "\(profile.cuisines.count)") }
                    NavigationLink { BudgetEditView() } label: { row("dollarsign.circle", String(localized: "Budget"), profile.weeklyBudget.map { "\(Money.format($0))/wk" } ?? String(localized: "Flexible")) }
                }

                Section("Shopping") {
                    NavigationLink { StoresEditView() } label: {
                        row("storefront", String(localized: "Where I shop"),
                            profile.postalCode.isEmpty ? String(localized: "Not set") : "\(profile.postalCode) · \(store.myStoreIds.count)")
                    }
                    NavigationLink { StrategyEditView() } label: { row("scalemass", String(localized: "Shopping Strategy"), profile.strategy.title) }
                }

                Section("App") {
                    Toggle(isOn: Binding(get: { profile.usesMetric }, set: { v in store.updateProfile { $0.usesMetric = v } })) {
                        Label("Metric units", systemImage: "ruler")
                    }
                    .tint(BW.leaf)
                    // Changes the app language directly (not the iPhone settings).
                    Picker(selection: Binding(get: { LanguageState.shared.current }, set: { AppLanguage.set($0) })) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(verbatim: "\(language.flag) \(language.nativeName)").tag(language)
                        }
                    } label: {
                        Label("Language", systemImage: "character.bubble")
                    }
                    .tint(BW.inkSecondary)
                    NavigationLink { CurrencyEditView() } label: {
                        row("banknote", String(localized: "Currency"), "\(CurrencyState.shared.current.flag) \(CurrencyState.shared.current.rawValue)")
                    }
                    NavigationLink { NotificationsEditView() } label: { Label("Notifications", systemImage: "bell") }
                    NavigationLink { PrivacyView() } label: { Label("Privacy", systemImage: "hand.raised") }
                }

                Section {
                    Button("Sign Out") { store.signOut() }
                    Button("Delete Account", role: .destructive) { confirmDelete = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BW.canvas)
            .foregroundStyle(BW.ink)
            .navigationTitle("Profile")
            .bitewiseDestinations()
            .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { store.deleteAccount() }
            } message: {
                Text("This removes your profile, swipes, saves and grocery lists.")
            }
        }
    }

    private var mealTypeText: String {
        let picked = MealType.allCases.filter { profile.mealTypes.contains($0) }
        return picked.isEmpty ? String(localized: "All") : picked.map(\.title).joined(separator: ", ")
    }

    private var allergyText: String {
        let items = profile.allergyNames.sorted()
        return items.isEmpty ? String(localized: "None") : items.joined(separator: ", ")
    }

    private var savedThisWeek: Double {
        let cal = Calendar.current
        return store.data.cookLogs.filter { $0.madeWithDeal && cal.isDate($0.date, equalTo: .now, toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.savings }
    }

    private var weekGoal: Double { store.data.profile.weeklyBudget ?? 25 }

    private var header: some View {
        let left = max(0, weekGoal - savedThisWeek)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text("You saved this week")
                    .font(.bw(.caption, weight: .heavy))
                    .foregroundStyle(Color(hex: 0xEFD35A))
                    .textCase(.uppercase)
                Spacer()
                Button { path.append(Route.streaks) } label: {
                    Text(String(localized: "\(store.wiseStreakDays) days"))
                        .font(.bw(.caption, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .center, spacing: 8) {
                Text(Money.format(savedThisWeek))
                    .font(.bw(size: 48, weight: .heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer(minLength: 0)
                MascotView(name: BWImage.mascotCheer, size: 78)
            }
            Text(String(localized: "Goal \(Money.format(weekGoal)) / week · \(Money.format(left)) to go"))
                .font(.bw(.footnote, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            ProgressView(value: min(savedThisWeek / max(weekGoal, 1), 1))
                .tint(Color(hex: 0xEFD35A))
            weekBars
        }
        .padding(18)
        .background(BW.ink, in: .rect(cornerRadius: 28))
    }

    private var weekBars: some View {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let amounts: [Double] = (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: start) ?? start
            return store.data.cookLogs.filter { $0.madeWithDeal && cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.savings }
        }
        let peak = max(amounts.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(0..<7, id: \.self) { index in
                let day = cal.date(byAdding: .day, value: index, to: start) ?? start
                let today = cal.isDateInToday(day)
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(today ? Color(hex: 0xEFD35A) : (amounts[index] > 0 ? BW.leaf : Color.white.opacity(0.25)))
                        .frame(width: 18, height: max(4, 46 * amounts[index] / peak))
                    Text(shortDay(day))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func shortDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = AppLanguage.current.locale
        f.setLocalizedDateFormatFromTemplate("EEEEE")
        return f.string(from: date)
    }

    private var statGrid: some View {
        let meals = store.data.cookLogs.count
        let average = meals > 0 ? store.totalSaved / Double(meals) : 0
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                statCard(String(localized: "This month"), Money.format(store.savedThisMonth), accent: false)
                statCard(String(localized: "Since you joined"), Money.format(store.totalSaved), accent: false)
            }
            HStack(spacing: 10) {
                statCard(String(localized: "Meals eaten"), "\(meals)", accent: false)
                statCard(String(localized: "Avg per meal"), Money.format(average), accent: true)
            }
        }
    }

    private func statCard(_ title: String, _ value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.bw(.caption, weight: .medium))
                .foregroundStyle(BW.inkSecondary)
            Text(value)
                .font(.bw(.title2))
                .foregroundStyle(accent ? BW.leafDeep : BW.ink)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BW.card, in: .rect(cornerRadius: 18))
    }

    private func row(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer(minLength: 12)
            Text(value).foregroundStyle(BW.inkSecondary).lineLimit(1)
        }
    }
}

// MARK: - Subscription

/// Current plan, renewal or trial date, monthly -> yearly switch, Apple's manage/cancel sheet and restore.
struct SubscriptionSummary: View {
    @Environment(AppStore.self) private var store
    @State private var switching = false
    @State private var message: String?

    private var sub: SubscriptionService { store.subscription }
    private var isYearly: Bool { sub.activeProductId == SubscriptionService.annualId }
    private var isMonthly: Bool { sub.activeProductId == SubscriptionService.monthlyId }
    private var date: String { sub.expirationDate?.formatted(date: .long, time: .omitted) ?? "" }

    private var planName: String {
        if isYearly { return sub.isInTrial ? String(localized: "Lemora Yearly · free trial") : String(localized: "Lemora Yearly") }
        if isMonthly { return String(localized: "Lemora Monthly") }
        return String(localized: "Your Lemora plan is active")
    }

    private var status: String? {
        guard sub.expirationDate != nil else { return nil }
        if sub.isInTrial {
            return sub.willRenew
                ? String(localized: "Free trial ends \(date). Cancel before then and you won’t be charged.")
                : String(localized: "Free trial cancelled. You keep access until \(date).")
        }
        if !sub.willRenew { return String(localized: "Cancelled. You keep access until \(date).") }
        return isYearly
            ? String(localized: "Renews \(date). If you cancel, you keep access until then and the next year isn’t charged.")
            : String(localized: "Renews \(date). Cancel anytime; you keep access until then.")
    }

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                Label(planName, systemImage: "checkmark.seal.fill").foregroundStyle(BW.leafDeep)
                if let status {
                    Text(status).font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                }
            }
            .task { await sub.refreshEntitlements() }
            if isMonthly, let annual = sub.annual {
                Button {
                    Task { await switchToYearly(annual) }
                } label: {
                    HStack {
                        Text("Switch to yearly · \(annual.displayPrice)/year")
                        Spacer()
                        if switching { ProgressView() }
                    }
                }
                .disabled(switching)
            }
            Button("Manage or cancel subscription") { Task { await sub.showManageSubscriptions() } }
            Button("Restore purchases") { Task { await sub.restore() } }
            if let message {
                Text(message).font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
            }
        }
    }

    private func switchToYearly(_ annual: Product) async {
        switching = true
        defer { switching = false }
        do {
            if try await sub.purchase(annual) {
                message = String(localized: "You’re on the yearly plan.")
            }
        } catch {
            message = String(localized: "The change didn’t go through. Please try again.")
        }
    }
}

// MARK: - Editors (reuse onboarding steps so everything stays editable)

/// Shows one onboarding screen (same cards, emojis and Zesty bubble) to edit a saved preference.
/// Changes are saved when leaving the screen; only the edited field is written back.
struct OnboardingPrefEditor<Content: View>: View {
    @Environment(AppStore.self) private var store
    @State private var model: OnboardingModel?
    let screen: OnboardingModel.Screen
    let title: String
    let subtitle: String
    let mood: ZestyMascot.Mood
    let apply: @MainActor (OnboardingModel, inout UserProfile) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            OB.cream.ignoresSafeArea()
            if let model {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center, spacing: 10) {
                            ZestyMascot(mood: mood, size: 64, seedKey: "pf-" + screen.rawValue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title).font(OB.font(20, 800)).foregroundStyle(OB.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(subtitle).font(OB.font(13, 500)).foregroundStyle(OB.sub)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white, in: .rect(cornerRadius: 24))
                            .shadow(color: OB.ink.opacity(0.06), radius: 8, x: 0, y: 3)
                        }
                        content()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
                .environment(model)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sensoryFeedback(.selection, trigger: model?.hapticKey)
        .onChange(of: model?.location.state) { _, state in
            guard let model, let state else { return }
            switch state {
            case .resolved(let code): model.applyDevicePostal(code)
            case .denied, .failed: model.locationFailed()
            default: break
            }
        }
        .onAppear {
            guard model == nil else { return }
            let m = OnboardingModel(entry: .signedOut)
            m.a = OnboardingAnswers(profile: store.data.profile)
            m.screen = screen
            model = m
        }
        .onDisappear {
            guard let model else { return }
            store.updateProfile { apply(model, &$0) }
        }
    }
}

extension OnboardingAnswers {
    /// Onboarding answers matching a saved profile, so the profile editors can reuse the onboarding screens.
    init(profile p: UserProfile) {
        self.init()
        let goals: [Goal: String] = [.saveMoney: "save_money", .eatHealthier: "eat_healthier", .loseWeight: "lose_weight",
                                     .buildMuscle: "build_muscle", .gainWeight: "gain_weight", .maintain: "maintain_weight",
                                     .discover: "discover_meals", .mealPrep: "meal_prep"]
        goal = goals[p.goal] ?? "save_money"
        self.goals = p.allGoals.compactMap { goals[$0] }
        unit = p.usesMetric ? "kg" : "lb"
        let cuisines: [Cuisine: String] = [.italian: "italian", .mexican: "mexican", .japanese: "japanese", .korean: "korean",
                                           .indian: "indian", .greek: "greek", .middleEastern: "lebanese", .french: "french",
                                           .thai: "thai", .vietnamese: "vietnamese", .caribbean: "caribbean", .american: "comfort"]
        if p.cuisines.isEmpty || p.cuisines.isSuperset(of: Set(Cuisine.allCases)) {
            self.cuisines = ["all"]
        } else {
            self.cuisines = cuisines.filter { p.cuisines.contains($0.key) }.map(\.value).sorted()
        }
        let diets: [DietPreference: String] = [.plantBased: "plant_based", .wholeFood: "whole_food", .mediterranean: "mediterranean",
                                               .flexitarian: "flexitarian", .pescatarian: "pescatarian", .vegetarian: "vegetarian",
                                               .vegan: "vegan", .lowCarb: "low_carb", .keto: "keto", .highProtein: "high_protein",
                                               .glutenFree: "gluten_free", .lactoseFree: "lactose_free", .halal: "halal", .kosher: "kosher"]
        let picked = diets.filter { p.diets.contains($0.key) }.map(\.value).sorted()
        self.diets = picked.isEmpty ? ["none"] : picked
        allergies = p.allergyRefs.filter { $0.kind == .allergen }.map { $0.id == "tree_nuts" ? "tree_nut" : $0.id }
        noAllergy = p.hasNoAllergies
        dislikes = p.dislikedIngredients.map { Dislike(id: $0.id, name: $0.name) }
        meals = MealType.allCases.filter { p.mealTypes.contains($0) }.map(\.rawValue)
        household = max(1, p.householdSize)
        noBudget = p.weeklyBudget == nil
        budget = Int((p.weeklyBudget ?? 120).rounded())
        budgetTouched = true
        switch p.strategy {
        case .convenience: strategy = "one"
        case .maximumSavings: strategy = "max"
        default: strategy = "balanced"
        }
        referral = "other"
        reachedPlan = true
        if let country = p.location.country {
            self.country = country.code
            postal = p.location.postalCode
            locMode = p.location.source == .device ? "auto" : "manual"
        }
        let names = Dictionary(OnboardingModel.storeIds.map { ($0.value, $0.key) }, uniquingKeysWith: { a, _ in a })
        var pickedStores = p.storePreferences.filter { $0.value != .doNotRecommend }.keys
            .map { names[$0] ?? RetailerCatalog.byId[$0]?.name ?? $0 }
        if p.shopsAtCostco && !pickedStores.contains("Costco") { pickedStores.append("Costco") }
        stores = pickedStores.sorted()
    }
}

private struct ProfileEditor<Content: View>: View {
    @Environment(AppStore.self) private var store
    @State private var draft: UserProfile = UserProfile()
    @State private var loaded: Bool = false
    let content: (Binding<UserProfile>) -> Content

    var body: some View {
        content($draft)
            .background(BW.canvas)
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                if !loaded { draft = store.data.profile; loaded = true }
            }
            .onDisappear {
                store.updateProfile { $0 = draft }
            }
    }
}

struct GoalEditView: View {
    var body: some View {
        OnboardingPrefEditor(screen: .goal, title: "What are your goals?", subtitle: "Pick all that apply. This shapes everything I recommend.", mood: .idea,
                             apply: { m, p in
                                 let new = m.makeProfile(base: p)
                                 p.goal = new.goal
                                 p.goals = new.goals
                             }) {
            OBGoalStep()
        }
    }
}
struct DietEditView: View {
    var body: some View {
        OnboardingPrefEditor(screen: .diet, title: "Do you follow a specific diet?", subtitle: "Pick all that apply. I’ll keep them compatible.", mood: .talking,
                             apply: { m, p in
                                 let new = m.makeProfile(base: p)
                                 p.diets = new.diets
                             }) {
            OBDietStep()
        }
    }
}
struct AllergyEditView: View {
    var body: some View {
        OnboardingPrefEditor(screen: .allergies, title: "Do you have any food allergies?", subtitle: "These are strict. I’ll never show recipes with them.", mood: .curious,
                             apply: { m, p in
                                 let new = m.makeProfile(base: p)
                                 let kept = p.allergyRefs.filter { old in old.kind == .ingredient && !new.allergyRefs.contains { $0.id == old.id } }
                                 p.hasNoAllergies = new.hasNoAllergies
                                 p.allergyRefs = new.allergyRefs + kept
                             }) {
            OBAllergyStep()
        }
    }
}
struct DislikeEditView: View {
    var body: some View {
        OnboardingPrefEditor(screen: .dislikes, title: "Anything you’d rather not eat?", subtitle: "Tap a few or search any ingredient.", mood: .talking,
                             apply: { m, p in
                                 let new = m.makeProfile(base: p)
                                 p.dislikedIngredients = new.dislikedIngredients
                             }) {
            OBDislikeStep()
        }
    }
}
struct CuisineEditView: View {
    var body: some View {
        OnboardingPrefEditor(screen: .branch, title: "What do you love eating?", subtitle: "Pick a few. Swipes refine the rest.", mood: .idle,
                             apply: { m, p in
                                 let new = m.makeProfile(base: p)
                                 p.cuisines = new.cuisines
                             }) {
            OBTasteStep()
        }
    }
}
struct MealTypeEditView: View {
    var body: some View {
        OnboardingPrefEditor(screen: .meals, title: "What kind of recipes are you looking for?", subtitle: "Pick the meals you want ideas for.", mood: .idea,
                             apply: { m, p in
                                 let new = m.makeProfile(base: p)
                                 p.mealTypes = new.mealTypes
                             }) {
            OBMealStep()
        }
    }
}

struct MealTypeStep: View {
    @Binding var profile: UserProfile

    var body: some View {
        StepScaffold(title: String(localized: "What kind of recipes are you looking for?"),
                     subtitle: String(localized: "Pick the meals you want ideas for. Pick none to see everything.")) {
            ChipFlow(items: MealType.allCases) { meal in
                ChoiceChip(title: meal.emoji + " " + meal.title, selected: profile.mealTypes.contains(meal)) {
                    if profile.mealTypes.contains(meal) { profile.mealTypes.remove(meal) } else { profile.mealTypes.insert(meal) }
                }
            }
        }
    }
}
struct BudgetEditView: View {
    var body: some View {
        OnboardingPrefEditor(screen: .budget, title: "What’s your weekly grocery budget?", subtitle: "For your whole household.", mood: .thinking,
                             apply: { m, p in
                                 let new = m.makeProfile(base: p)
                                 p.weeklyBudget = new.weeklyBudget
                                 p.householdSize = new.householdSize
                             }) {
            OBBudgetStep()
            OBText("How many people do you cook for each week?", 17, 800).padding(.top, 8)
            OBPeopleStep()
        }
    }
}
/// "Where do you shop?": postal code or ZIP (typed, or from Location Services), then the stores near it.
struct StoresEditView: View {
    var body: some View {
        OnboardingPrefEditor(
            screen: .stores,
            title: "Where do you shop?",
            subtitle: "Type your postal code or ZIP, or share your location. Then pick the stores you shop at.",
            mood: .cart,
            apply: { model, profile in
                let updated = model.makeProfile(base: profile)
                if model.currentLocation != nil { profile.location = updated.location }
                profile.storePreferences = updated.storePreferences
                profile.shopsAtCostco = updated.shopsAtCostco
            }
        ) {
            OBLocationStep()
            OBText("Your stores", 17, 800).padding(.top, 8)
            OBStoresStep()
        }
    }
}
struct StrategyEditView: View {
    var body: some View {
        OnboardingPrefEditor(screen: .strategy, title: "How do you like to shop?", subtitle: "I’ll plan your list around this.", mood: .cart,
                             apply: { m, p in
                                 let new = m.makeProfile(base: p)
                                 p.strategy = new.strategy
                                 p.maxStores = new.maxStores
                             }) {
            OBStrategyStep()
        }
    }
}
struct LocationEditView: View {
    var body: some View { StoresEditView() }
}

struct NotificationsEditView: View {
    @Environment(AppStore.self) private var store
    @State private var prefs: NotificationPrefs = NotificationPrefs()

    var body: some View {
        List {
            Section {
                Toggle("Deal alerts", isOn: $prefs.dealAlerts)
                Toggle("Recipe recommendations", isOn: $prefs.recommendations)
                Toggle("Saved recipe price drops", isOn: $prefs.priceDrops)
                Toggle("Weekly Lemora recap", isOn: $prefs.weeklyRecap)
            } footer: {
                Text("We only notify you when something is genuinely worth it. Never just because a flyer updated.")
            }
        }
        .tint(BW.leaf)
        .scrollContentBackground(.hidden)
        .background(BW.canvas)
        .navigationTitle("Notifications")
        .toolbar(.hidden, for: .tabBar)
        .onAppear { prefs = store.data.notifications }
        .onChange(of: prefs) { _, new in store.updateNotifications(new) }
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("What we use") {
                Text("Location: only when you open the app, to find nearby stores. You can use a postal code instead.")
                Text("Profile & goals: to personalize recipes. Lemora is not medical advice and never promises health outcomes.")
                Text("Usage analytics: anonymous events that help us improve recommendations.")
            }
            Section("Your control") {
                Text("Everything from onboarding can be edited in Profile. Deleting your account removes your data.")
            }
        }
        .font(.bw(.subheadline, weight: .regular))
        .scrollContentBackground(.hidden)
        .background(BW.canvas)
        .navigationTitle("Privacy")
        .toolbar(.hidden, for: .tabBar)
    }
}
