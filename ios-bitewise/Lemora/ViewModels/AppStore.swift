import Foundation
import SwiftUI

/// Single source of app state. Views read from it and call intent methods; business rules live here
/// and in the engines, never in views.
@Observable
final class AppStore {
    private(set) var data: AppData
    private(set) var config = RemoteConfig()
    private(set) var deals: [Deal] = []
    private(set) var prices: [String: RecipePrice] = [:]
    private(set) var ranked: [ScoredRecipe] = []
    private(set) var liveDealsLoaded = false
    private(set) var dealLoadError: String?

    let subscription = SubscriptionService()
    let recipes: [Recipe] = RecipeCatalog.all

    private let repository: UserDataRepository
    private let analytics: AnalyticsTracking
    private let configProvider: RemoteConfigProvider
    private let engine = RecommendationEngine()
    private let pricing = PricingEngine()
    private let zesty = ZestyService()
    private var availableDeals: [Deal] = []
    private var sessionPosition = 0

    init(repository: UserDataRepository = LocalUserDataRepository(),
         analytics: AnalyticsTracking = LogAnalytics(),
         configProvider: RemoteConfigProvider = BundledRemoteConfigProvider()) {
        self.repository = repository
        self.analytics = analytics
        self.configProvider = configProvider
        self.data = repository.load() ?? AppData()
        refreshDeals()
    }

    // MARK: Lifecycle

    func bootstrap() async {
        config = await configProvider.fetch()
        await subscription.start()
        await loadLiveDeals()
        markActive()
        analytics.track("app_opened", [:])
    }

    private func persist() {
        repository.save(data)
    }

    func mutate(_ change: (inout AppData) -> Void) {
        change(&data)
        persist()
    }

    func track(_ event: String, _ props: [String: String] = [:]) {
        analytics.track(event, props)
    }

    // MARK: Account

    var isSignedIn: Bool { data.account != nil }

    func signIn(name: String, email: String) {
        mutate { $0.account = Account(name: name, email: email, createdAt: .now) }
        markActive()
        track("account_created")
    }

    func signOut() {
        mutate { $0.account = nil }
        OnboardingModel.clearSaved()
    }

    func deleteAccount() {
        repository.wipe()
        data = AppData()
        refreshDeals()
    }

    // MARK: Onboarding

    func completeOnboarding(with profile: UserProfile) {
        mutate {
            $0.profile = profile
            $0.onboardingComplete = true
        }
        Task { await loadLiveDeals() }
        track("onboarding_completed", ["goal": profile.goal.rawValue])
    }

    func finishPaywall() {
        mutate {
            $0.paywallSeen = true
            if $0.welcomeSeen == nil { $0.welcomeSeen = false }
        }
    }

    var needsWelcome: Bool { data.welcomeSeen == false }

    func finishWelcome() {
        mutate { $0.welcomeSeen = true }
        track("welcome_completed")
    }

    /// Records a started free trial and schedules the real reminder shown on the paywall timeline.
    func recordTrialStart(days: Int, priceText: String) {
        mutate { $0.trialEndsAt = Calendar.current.date(byAdding: .day, value: days, to: .now) }
        track("trial_started", ["days": "\(days)"])
        Task { await TrialReminderService.schedule(trialDays: days, priceText: priceText) }
    }

    /// Personalized preview of the plan built from onboarding answers (before it is saved).
    func planPreview(for profile: UserProfile) -> PlanPreview {
        let now = Date.now
        let mine = Set(profile.storePreferences.filter { $0.value != .doNotRecommend }.map(\.key))
        var blocked = Set(profile.storePreferences.filter { $0.value == .doNotRecommend }.map(\.key))
        if !profile.shopsAtCostco { blocked.insert("costco") }
        let source = availableDeals.isEmpty ? SampleDealProvider.deals(now: now) : availableDeals
        let active = source.filter { $0.isActive(at: now) && !blocked.contains($0.retailerId) }
        let scoped = mine.isEmpty ? active : active.filter { mine.contains($0.retailerId) }
        let previewPrices = Dictionary(uniqueKeysWithValues: recipes.map {
            ($0.id, pricing.price(recipe: $0, servings: $0.servings, deals: scoped))
        })
        let matches = engine.rank(recipes: recipes, profile: profile, taste: [:], seen: [],
                                  prices: previewPrices, weights: config.weights)
        let perServing = matches.isEmpty ? 0 : matches.map(\.price.perServing).reduce(0, +) / Double(matches.count)
        let topSavings = matches.map(\.price.savings).sorted(by: >).prefix(3).reduce(0, +)
        let names = mine.compactMap { RetailerCatalog.byId[$0]?.name }.sorted()
        return PlanPreview(matches: matches, excludedCount: recipes.count - matches.count, dealCount: scoped.count,
                           storeNames: names, averagePerServing: perServing, sampleWeeklySavings: topSavings)
    }

    func updateProfile(_ change: (inout UserProfile) -> Void) {
        let previousPostalCode = data.profile.postalCode
        mutate { change(&$0.profile) }
        if data.profile.postalCode != previousPostalCode {
            Task { await loadLiveDeals() }
        } else {
            refreshDeals()
        }
    }

    func updateNotifications(_ prefs: NotificationPrefs) {
        mutate { $0.notifications = prefs }
    }

    // MARK: Entitlements

    /// Full app access is granted only by a verified StoreKit entitlement.
    // TEMPORARY (beta): tester bypass for the hard paywall. Remove before public release.
    var testerBypass: Bool = UserDefaults.standard.bool(forKey: "lemora.testerBypass")
    func enableTesterBypass() {
        testerBypass = true
        UserDefaults.standard.set(true, forKey: "lemora.testerBypass")
    }

    var isPremium: Bool { subscription.hasActiveSubscription || testerBypass }

    func has(_ entitlement: Entitlement) -> Bool { isPremium }

    func onSubscriptionChanged() {
        guard isPremium else { return }
        mutate { for i in $0.saved.indices { $0.saved[i].expiresAt = nil } }
    }

    // MARK: Deals & pricing

    /// Retailers the user accepts (preferred or acceptable). Empty means none chosen yet.
    var myStoreIds: Set<String> {
        Set(data.profile.storePreferences.filter { $0.value != .doNotRecommend }.map(\.key))
    }

    var blockedStoreIds: Set<String> {
        var blocked = Set(data.profile.storePreferences.filter { $0.value == .doNotRecommend }.map(\.key))
        if !data.profile.shopsAtCostco { blocked.insert("costco") }
        return blocked
    }

    /// Active, non-expired deals from stores the user hasn't excluded.
    func refreshDeals() {
        let now = Date.now
        if availableDeals.isEmpty && !liveDealsLoaded {
            availableDeals = SampleDealProvider.deals(now: now)
        }
        deals = availableDeals.filter {
            $0.isActive(at: now)
                && !blockedStoreIds.contains($0.retailerId)
                && isDealCompatible($0, profile: data.profile)
        }
        refreshRanking()
    }

    /// Applies the user's food exclusions before deals power Steals, recipes,
    /// grocery lists, Discover, Ask, or meal pricing.
    private func isDealCompatible(_ deal: Deal, profile: UserProfile) -> Bool {
        if profile.dislikedIngredients.contains(where: { $0.id == deal.ingredientId }) { return false }
        if profile.allergyRefs.contains(where: { $0.kind == .ingredient && $0.id == deal.ingredientId }) { return false }

        for allergen in profile.allergies {
            let state = deal.allergenFlags[allergen.rawValue] ?? deal.allergenFlags[allergen.databaseId]
            if state == "contains" || state == "may_contain" || state == "mayContain" { return false }
        }

        let flags: [DietPreference: String] = [
            .vegetarian: "vegetarian", .vegan: "vegan", .pescatarian: "pescatarian",
            .keto: "keto", .lowCarb: "low_carb", .highProtein: "high_protein",
            .glutenFree: "gluten_free", .dairyFree: "dairy_free", .lactoseFree: "lactose_free",
            .halal: "halal", .kosher: "kosher",
        ]
        for diet in profile.diets where diet.isStrict {
            // A strict diet requires positive confirmation. "Unknown" is never treated as safe.
            if let key = flags[diet], deal.dietaryFlags[key] != "yes" { return false }
        }
        return true
    }

    /// Replaces development fixtures with the current, food-only weekly flyer feed.
    /// A valid location with no coverage intentionally returns no deals instead of showing another region.
    func loadLiveDeals() async {
        do {
            let fetched = try await SupabaseService.shared.fetchActiveDeals(location: data.profile.location)
            availableDeals = fetched
            liveDealsLoaded = true
            dealLoadError = nil
            refreshDeals()
        } catch {
            dealLoadError = error.localizedDescription
            if !liveDealsLoaded {
                availableDeals = SampleDealProvider.deals(now: .now)
                refreshDeals()
            }
            analytics.track("live_deals_load_failed", ["error": error.localizedDescription])
        }
    }

    func deals(myStoresOnly: Bool) -> [Deal] {
        guard myStoresOnly, !myStoreIds.isEmpty else { return deals }
        return deals.filter { myStoreIds.contains($0.retailerId) }
    }

    func price(for recipe: Recipe, servings: Int? = nil) -> RecipePrice {
        if servings == nil || servings == recipe.servings, let cached = prices[recipe.id] { return cached }
        return pricing.price(recipe: recipe, servings: servings ?? recipe.servings, deals: pricingDeals)
    }

    private var pricingDeals: [Deal] {
        myStoreIds.isEmpty ? deals : deals.filter { myStoreIds.contains($0.retailerId) }
    }

    private func refreshRanking() {
        let scoped = pricingDeals
        prices = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, pricing.price(recipe: $0, servings: $0.servings, deals: scoped)) })
        let seen = Set(data.swipes.map(\.recipeId))
        ranked = engine.rank(recipes: recipes, profile: data.profile, taste: data.tasteWeights, seen: seen,
                             prices: prices, weights: config.weights)
    }

    func scored(_ recipe: Recipe) -> ScoredRecipe {
        if let hit = ranked.first(where: { $0.id == recipe.id }) { return hit }
        return engine.score(recipe, price: price(for: recipe), profile: data.profile, taste: data.tasteWeights,
                            seen: [], weights: config.weights)
    }

    func exclusionReason(for recipe: Recipe) -> String? {
        engine.exclusionReason(for: recipe, profile: data.profile)
    }

    func compatibility(of recipe: Recipe) -> [(DietPreference, TriState)] { engine.compatibility(of: recipe) }
    func allergens(of recipe: Recipe) -> (contains: [Allergen], mayContain: [Allergen]) { engine.allergens(of: recipe) }

    /// Worth It This Week: safe, personalized recipes that currently use deals.
    var worthIt: [ScoredRecipe] {
        ranked.filter { $0.price.dealCount > 0 }.sorted {
            let lhs = $0.price.weeklyValueScore * 0.85 + $0.score * 0.15
            let rhs = $1.price.weeklyValueScore * 0.85 + $1.score * 0.15
            return lhs > rhs
        }
    }

    func recipesUsing(ingredientId: String) -> [ScoredRecipe] {
        ranked.filter { recipe in
            recipe.recipe.ingredients.contains {
                PricingEngine.recipeIngredient($0.ingredientId, matches: ingredientId)
            }
        }
    }

    /// Steals: deals ordered by real value (discount with confidence). Deals without history rank last.
    func steals(myStoresOnly: Bool) -> [Deal] {
        deals(myStoresOnly: myStoresOnly).sorted { a, b in
            let fallbackA = max(a.dealScore, Double(a.discountPercent ?? 0)) * 0.50
                + a.commonFoodScore * 0.30 + a.healthPriorityScore * 0.20
            let fallbackB = max(b.dealScore, Double(b.discountPercent ?? 0)) * 0.50
                + b.commonFoodScore * 0.30 + b.healthPriorityScore * 0.20
            let av = (a.recommendationScore > 0 ? a.recommendationScore : fallbackA) * (a.confidence == .high ? 1.05 : 1)
            let bv = (b.recommendationScore > 0 ? b.recommendationScore : fallbackB) * (b.confidence == .high ? 1.05 : 1)
            return av > bv
        }
    }

    // MARK: Discover

    private var queueCutoff: Date { data.queueResetDate ?? .distantPast }

    var discoverQueue: [ScoredRecipe] {
        let swiped = Set(data.swipes.filter { $0.timestamp > queueCutoff }.map(\.recipeId))
        return ranked.filter { !swiped.contains($0.id) }
    }

    var calibrationDone: Int { data.swipes.filter(\.wasCalibration).count }
    var isCalibrating: Bool { calibrationDone < config.calibrationSwipes }

    var swipesToday: Int {
        data.swipes.filter { !$0.wasCalibration && Calendar.current.isDateInToday($0.timestamp) }.count
    }

    var swipesRemaining: Int? {
        if has(.unlimitedSwipes) || isCalibrating { return nil }
        return max(0, config.dailySwipeLimit - swipesToday)
    }

    var canSwipe: Bool { swipesRemaining.map { $0 > 0 } ?? true }

    func swipe(_ item: ScoredRecipe, _ direction: SwipeDirection) {
        guard canSwipe else { return }
        sessionPosition += 1
        let calibrating = isCalibrating
        let event = SwipeEvent(recipeId: item.id, direction: direction, timestamp: .now,
                               engineVersion: RecommendationEngine.version, positionInSession: sessionPosition,
                               reasonCodes: item.reasons.map(\.code.rawValue), wasCalibration: calibrating)
        let learned = engine.learn(from: item.recipe, direction: direction, weights: data.tasteWeights)
        mutate {
            $0.swipes.append(event)
            $0.tasteWeights = learned
        }
        if direction == .like { save(item.recipe) }
        markActive()
        refreshRanking()
        track(direction == .like ? "recipe_swiped_right" : "recipe_swiped_left", ["recipe": item.id])
    }

    func restartDiscovery() {
        mutate { $0.queueResetDate = .now }
    }

    // MARK: Saved

    var activeSaved: [SavedRecipe] {
        let now = Date.now
        return data.saved.filter { ($0.expiresAt ?? .distantFuture) > now }.sorted { $0.savedAt > $1.savedAt }
    }

    func isSaved(_ recipe: Recipe) -> Bool {
        activeSaved.contains { $0.recipeId == recipe.id }
    }

    func savedEntry(_ recipe: Recipe) -> SavedRecipe? {
        activeSaved.first { $0.recipeId == recipe.id }
    }

    func save(_ recipe: Recipe) {
        let expiry: Date? = has(.permanentSaves) ? nil : Date.now.addingTimeInterval(Double(config.temporarySaveHours) * 3600)
        mutate {
            $0.saved.removeAll { $0.recipeId == recipe.id }
            $0.saved.append(SavedRecipe(recipeId: recipe.id, savedAt: .now, expiresAt: expiry))
        }
        track("recipe_saved", ["recipe": recipe.id])
    }

    func unsave(_ recipe: Recipe) {
        mutate { $0.saved.removeAll { $0.recipeId == recipe.id } }
    }

    // MARK: Grocery list

    func addToGrocery(_ recipe: Recipe, servings: Int) {
        let p = price(for: recipe, servings: servings)
        var addedDeal = false
        mutate { d in
            for line in p.lines {
                if let idx = d.grocery.firstIndex(where: { $0.ingredientId == line.ingredientId && $0.unit == line.unit && !$0.isChecked }) {
                    d.grocery[idx].quantity += line.quantity
                    d.grocery[idx].estimatedCost += line.cost
                    if !d.grocery[idx].recipeIds.contains(recipe.id) { d.grocery[idx].recipeIds.append(recipe.id) }
                } else {
                    d.grocery.append(GroceryItem(ingredientId: line.ingredientId, quantity: line.quantity, unit: line.unit,
                                                 recipeIds: [recipe.id], dealId: line.deal?.id,
                                                 retailerId: line.deal?.retailerId, estimatedCost: line.cost))
                }
                if line.deal != nil && line.savings > 0 { addedDeal = true }
            }
            if addedDeal { d.savingsActions.append(SavingsAction(date: .now, kind: .addedDealToList)) }
        }
        markActive()
        track("grocery_list_updated", ["recipe": recipe.id])
    }

    func addDealToGrocery(_ deal: Deal) {
        mutate { d in
            if !d.grocery.contains(where: { $0.dealId == deal.id && !$0.isChecked }) {
                d.grocery.append(GroceryItem(ingredientId: deal.ingredientId, quantity: Double(deal.multiBuyQuantity ?? 1),
                                             unit: .unit, recipeIds: [], dealId: deal.id, retailerId: deal.retailerId,
                                             estimatedCost: deal.salePrice))
            }
            d.savingsActions.append(SavingsAction(date: .now, kind: .addedDealToList))
        }
        markActive()
        track("deal_added_to_list", ["deal": deal.id])
    }

    func toggleGrocery(_ id: UUID) {
        mutate { d in
            if let i = d.grocery.firstIndex(where: { $0.id == id }) { d.grocery[i].isChecked.toggle() }
        }
        track("ingredient_checked")
    }

    func removeGrocery(_ id: UUID) {
        mutate { $0.grocery.removeAll { $0.id == id } }
    }

    func clearCheckedGrocery() {
        mutate { $0.grocery.removeAll(where: \.isChecked) }
    }

    func dealById(_ id: String?) -> Deal? {
        guard let id else { return nil }
        return deals.first { $0.id == id }
    }

    // MARK: Cooking & savings

    @discardableResult
    func cook(_ recipe: Recipe) -> CookLog {
        let p = price(for: recipe)
        let log = CookLog(recipeId: recipe.id, date: .now, madeWithDeal: p.dealCount > 0, savings: p.savings)
        mutate { $0.cookLogs.append(log) }
        markActive()
        track("recipe_cooked", ["recipe": recipe.id])
        return log
    }

    func setMadeWithDeal(_ logId: UUID, _ value: Bool) {
        mutate { d in
            if let i = d.cookLogs.firstIndex(where: { $0.id == logId }) {
                let old = d.cookLogs[i]
                d.cookLogs[i] = CookLog(id: old.id, recipeId: old.recipeId, date: old.date, madeWithDeal: value, savings: old.savings)
            }
        }
    }

    func cookLog(_ id: UUID) -> CookLog? { data.cookLogs.first { $0.id == id } }

    func timesCooked(_ recipe: Recipe) -> Int { data.cookLogs.filter { $0.recipeId == recipe.id }.count }

    var totalSaved: Double { data.cookLogs.filter(\.madeWithDeal).reduce(0) { $0 + $1.savings } }

    var savedThisMonth: Double {
        let cal = Calendar.current
        return data.cookLogs.filter { $0.madeWithDeal && cal.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + $1.savings }
    }

    // MARK: Streaks

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func dayKey(_ date: Date) -> String { Self.dayFormatter.string(from: date) }

    func markActive() {
        guard isSignedIn else { return }
        let key = dayKey(.now)
        guard !data.activeDays.contains(key) else { return }
        mutate { $0.activeDays.append(key) }
    }

    /// Wise Streak: consecutive days with app activity, ending today (or yesterday).
    var wiseStreakDays: Int {
        let days = Set(data.activeDays)
        let cal = Calendar.current
        var cursor = Date.now
        if !days.contains(dayKey(cursor)) { cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor }
        var count = 0
        while days.contains(dayKey(cursor)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// Activity for Mon–Sun of the current week.
    var wiseWeek: [(label: String, active: Bool, isToday: Bool)] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let days = Set(data.activeDays)
        let symbols = ["M", "T", "W", "T", "F", "S", "S"]
        return (0..<7).map { i in
            let date = cal.date(byAdding: .day, value: i, to: start) ?? start
            return (symbols[i], days.contains(dayKey(date)), cal.isDateInToday(date))
        }
    }

    private func savingsWeekKeys() -> Set<String> {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let dates = data.cookLogs.filter(\.madeWithDeal).map(\.date) + data.savingsActions.map(\.date)
        return Set(dates.map { weekKey($0, cal) })
    }

    private func weekKey(_ date: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(c.yearForWeekOfYear ?? 0)-\(c.weekOfYear ?? 0)"
    }

    var savingsThisWeekDone: Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return savingsWeekKeys().contains(weekKey(.now, cal))
    }

    /// Savings Streak: consecutive weeks with at least one deal-linked action.
    var savingsStreakWeeks: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let weeks = savingsWeekKeys()
        var cursor = Date.now
        if !weeks.contains(weekKey(cursor, cal)) { cursor = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor }
        var count = 0
        while weeks.contains(weekKey(cursor, cal)) {
            count += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    // MARK: Ask

    /// Hidden daily cap on Ask questions. The number is never shown in the UI.
    private static let askDailyCap = 30

    var askLimitReached: Bool {
        (data.askUsage[dayKey(.now)] ?? 0) >= Self.askDailyCap
    }

    func ask(_ query: String, conversationId: String?) async throws -> ZestyAskResponse {
        let response = try await zesty.ask(
            message: query,
            conversationId: conversationId,
            data: data,
            acceptedStoreIds: myStoreIds,
            blockedStoreIds: blockedStoreIds
        )
        let key = dayKey(.now)
        mutate { $0.askUsage[key, default: 0] += 1 }
        track("ask_query_sent", ["model": response.model])
        return response
    }
}
