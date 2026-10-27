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
                    LemoraPageTitle(title: "Profile")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Section {
                    header
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    Button { path.append(Route.streaks) } label: { streakRow }
                        .listRowBackground(BW.lemonSoft)
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
                    NavigationLink { PantryView() } label: {
                        row("cabinet", String(localized: "Pantry"), store.pantryItems.isEmpty ? String(localized: "None") : String(localized: "\(store.pantryItems.count) items"))
                    }
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
            .toolbar(.hidden, for: .navigationBar)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                MascotView(name: BWImage.mascotCheer, size: 58, bob: true)
                    .frame(width: 72, height: 72)
                    .background(BW.lemonSoft, in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.data.account?.name ?? "")
                        .font(.bw(.title2, weight: .heavy)).foregroundStyle(BW.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if let email = store.data.account?.email, !email.isEmpty {
                        Text(email).font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
            }
            savingsCard
        }
        .padding(.vertical, 6)
        .onAppear { store.logPastPlannedMeals() }
    }

    /// Money saved with Lemora: meals cooked by hand plus planned meals whose day is over.
    private var savingsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lemoraText("Saved with Lemora", fr: "Économisé avec Lemora", es: "Ahorrado con Lemora"))
                        .font(.bw(.subheadline, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(Money.format(store.totalSaved))
                        .font(.bw(size: 50, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(BW.lemon)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .contentTransition(.numericText(value: store.totalSaved))
                }
                Spacer(minLength: 0)
                Image(BWImage.mascotCart)
                    .resizable().scaledToFit()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(BW.ink)
                    .frame(width: 30, height: 30)
                    .background(BW.lemon, in: .circle)
                Text(savingsHint)
                    .font(.bw(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(.white.opacity(0.09), in: .rect(cornerRadius: 22))
        }
        .padding(20)
        .background(Color(hex: 0x1F3B2F), in: .rect(cornerRadius: 26))
        .animation(.spring(response: 0.4), value: store.totalSaved)
    }

    private var savingsHint: String {
        let meals = store.mealsCookedCount
        guard store.totalSaved > 0.009 || meals > 0 else {
            return lemoraText("Check off a cooked meal to start", fr: "Coche un repas cuisiné pour commencer", es: "Marca una comida cocinada para empezar")
        }
        let month = Money.format(store.savedThisMonth)
        return lemoraText("\(meals) meals cooked · \(month) this month",
                          fr: "\(meals) repas cuisinés · \(month) ce mois-ci",
                          es: "\(meals) comidas cocinadas · \(month) este mes")
    }

    private var streakLevel: String {
        switch GrowthStage.forDays(store.wiseStreakDays) {
        case .sprout: lemoraText("Wise level", fr: "Niveau Sage", es: "Nivel Sabio")
        case .plant: lemoraText("Savvy level", fr: "Niveau Futé", es: "Nivel Astuto")
        case .lemon: lemoraText("Master level", fr: "Niveau Maître", es: "Nivel Maestro")
        }
    }

    private var streakRow: some View {
        let days = store.wiseStreakDays
        return HStack(spacing: 14) {
            Image(GrowthStage.forDays(days).imageName)
                .resizable().scaledToFit().frame(width: 34, height: 34)
                .frame(width: 56, height: 56)
                .background(.white, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(days == 1
                     ? lemoraText("Streak · 1 day", fr: "Série · 1 jour", es: "Racha · 1 día")
                     : lemoraText("Streak · \(days) days", fr: "Série · \(days) jours", es: "Racha · \(days) días"))
                    .font(.bw(.headline, weight: .heavy)).foregroundStyle(BW.ink)
                Text(streakLevel)
                    .font(.bw(.subheadline, weight: .medium)).foregroundStyle(BW.inkSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.headline.weight(.bold)).foregroundStyle(BW.ink)
        }
        .padding(.vertical, 6)
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
            .toolbar(.visible, for: .navigationBar)
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
