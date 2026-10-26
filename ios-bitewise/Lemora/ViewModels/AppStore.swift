import Foundation
import SwiftUI

/// Single source of app state. Views read from it and call intent methods; business rules live here
/// and in the engines, never in views.
@Observable
final class AppStore {
    private(set) var data: AppData
    private(set) var config = RemoteConfig()
    private(set) var deals: [Deal] = []
    private(set) var currentStorePrices: [StorePrice] = []
    private(set) var prices: [String: RecipePrice] = [:]
    private(set) var ranked: [ScoredRecipe] = []
    private(set) var liveDealsLoaded = false
    /// True while deals for a new area are being fetched (first visit of an area: ~40 s).
    private(set) var checkingNewArea = false
    /// When the current area load started (drives the ~1 min progress shown to the user).
    private(set) var checkingStartedAt = Date.now
    private var dealLoadID = 0
    private var lastDealsLoadAt: Date = .distantPast
    private(set) var dealLoadError: String?
    private(set) var currentPricesLoaded = false
    private(set) var currentPriceLoadError: String?

    let subscription = SubscriptionService()
    private(set) var recipes: [Recipe] = AppStore.launchRecipes()
    private var catalogueFromCache: Bool = FileManager.default.fileExists(atPath: SupabaseService.recipeCatalogueCacheURL.path)

    /// Cached catalogue (instant, no reshuffle at launch) plus the bundled original recipes.
    private static func launchRecipes() -> [Recipe] {
        let cached = SupabaseService.cachedRecipeCatalogue()
        guard !cached.isEmpty else { return RecipeCatalog.all }
        let ids = Set(cached.map(\.id))
        return cached + RecipeCatalog.all.filter { !ids.contains($0.id) }
    }
    private(set) var recipeCatalogueLoaded = false
    private(set) var recipeCatalogueError: String?

    private let repository: UserDataRepository
    private let analytics: AnalyticsTracking
    private let configProvider: RemoteConfigProvider
    private let engine = RecommendationEngine()
    private let pricing = PricingEngine()
    private let zesty = ZestyService()
    private var availableDeals: [Deal] = []
    private var availableStorePrices: [StorePrice] = []
    private var sessionPosition = 0

    init(repository: UserDataRepository = LocalUserDataRepository(),
         analytics: AnalyticsTracking = LogAnalytics(),
         configProvider: RemoteConfigProvider = BundledRemoteConfigProvider()) {
        self.repository = repository
        self.analytics = analytics
        self.configProvider = configProvider
        self.data = repository.load() ?? AppData()
        if data.likedIds == nil {
            var seen = Set<String>()
            var ids: [String] = []
            for id in data.swipes.reversed().compactMap({ $0.direction == .like ? $0.recipeId : nil })
                + data.saved.map(\.recipeId) {
                if seen.insert(id).inserted { ids.append(id) }
            }
            data.likedIds = ids
            repository.save(data)
        }
        refreshDeals()
    }

    // MARK: Lifecycle

    func bootstrap() async {
        syncCurrency()
        config = await configProvider.fetch()
        await subscription.start()
        await loadRecipeCatalogue()
        // Deals load in the background. The launch screen waits at most 3 s for them, never for a new area (~40 s).
        let dealsTask = Task { await loadLiveDeals(); await loadCurrentPrices() }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await dealsTask.value }
            group.addTask { try? await Task.sleep(for: .seconds(3)) }
            _ = await group.next()
            group.cancelAll()
        }
        analytics.track("app_opened", [:])
    }

    func loadRecipeCatalogue() async {
        do {
            let result = try await SupabaseService.shared.fetchRecipeCatalogue()
            let fetched = result.recipes
            if !fetched.isEmpty && (result.changed || !catalogueFromCache) {
                let fetchedIds = Set(fetched.map(\.id))
                recipes = fetched + RecipeCatalog.all.filter { !fetchedIds.contains($0.id) }
                refreshRanking()
            }
            catalogueFromCache = true
            recipeCatalogueLoaded = true
            recipeCatalogueError = nil
        } catch {
            recipeCatalogueError = error.localizedDescription
            analytics.track("recipe_catalogue_load_failed", ["error": error.localizedDescription])
        }
    }

    private func persist() {
        repository.save(data)
    }

    func mutate(_ change: (inout AppData) -> Void) {
        change(&data)
        persist()
        syncCurrency()
    }

    /// Currency follows the location entered at onboarding unless the user picked one in Profile.
    func syncCurrency() {
        CurrencyState.shared.sync(countryCode: data.profile.location.countryCode, postalCode: data.profile.postalCode)
    }

    func setCurrency(_ currency: AppCurrency?) {
        CurrencyState.shared.override = currency
        syncCurrency()
        track("currency_changed", ["currency": currency?.rawValue ?? "auto"])
    }

    func track(_ event: String, _ props: [String: String] = [:]) {
        analytics.track(event, props)
    }

    // MARK: Account

    var isSignedIn: Bool { data.account != nil }

    func signIn(name: String, email: String) {
        mutate { $0.account = Account(name: name, email: email, createdAt: .now) }
        track("account_created")
    }

    func signOut() {
        mutate { $0.account = nil }
        OnboardingModel.clearSaved()
    }

    func deleteAccount() {
        repository.wipe()
        data = AppData()
        availableDeals = []
        availableStorePrices = []
        refreshDeals()
    }

    // MARK: Onboarding

    func completeOnboarding(with profile: UserProfile) {
        mutate {
            $0.profile = profile
            $0.onboardingComplete = true
        }
        Task {
            await loadLiveDeals()
            await loadCurrentPrices()
        }
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
        let source = availableDeals
        let active = source.filter { $0.isActive(at: now) && !blocked.contains($0.retailerId) }
        let scoped = mine.isEmpty ? active : active.filter { mine.contains($0.retailerId) }
        let previewPrices = Dictionary(uniqueKeysWithValues: recipes.map {
            ($0.id, pricing.price(recipe: $0, servings: $0.servings, deals: scoped))
        })
        let matches = engine.rank(recipes: recipes, profile: profile, taste: [:], seen: [],
                                  prices: previewPrices, weights: config.weights)
        let knownPrices = matches.compactMap(\.price.perServing)
        let perServing = knownPrices.isEmpty ? 0 : knownPrices.reduce(0, +) / Double(knownPrices.count)
        let topSavings = matches.map(\.price.savings).sorted(by: >).prefix(3).reduce(0, +)
        let names = mine.compactMap { RetailerCatalog.byId[$0]?.name }.sorted()
        return PlanPreview(matches: matches, excludedCount: recipes.count - matches.count, dealCount: scoped.count,
                           storeNames: names, averagePerServing: perServing, sampleWeeklySavings: topSavings)
    }

    func updateProfile(_ change: (inout UserProfile) -> Void) {
        let previousLocation = data.profile.location
        mutate { change(&$0.profile) }
        if data.profile.location != previousLocation {
            Task {
                await loadLiveDeals()
                await loadCurrentPrices()
            }
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
        guard SubscriptionService.isTestFlight else { return }
        testerBypass = true
        UserDefaults.standard.set(true, forKey: "lemora.testerBypass")
    }

    var isPremium: Bool { subscription.hasActiveSubscription || (testerBypass && SubscriptionService.isTestFlight) }

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
        currentStorePrices = availableStorePrices.filter {
            $0.staleAfter >= now
                && !blockedStoreIds.contains($0.retailerId)
                && isPriceCompatible($0, profile: data.profile)
        }
        let flyerDeals = availableDeals.filter {
            $0.isActive(at: now)
                && !blockedStoreIds.contains($0.retailerId)
                && isDealCompatible($0, profile: data.profile)
        }
        // Weekly promotions come only from this week's flyers: shelf-price discount flags can be weeks old.
        deals = flyerDeals
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

    private func isPriceCompatible(_ price: StorePrice, profile: UserProfile) -> Bool {
        if profile.dislikedIngredients.contains(where: { $0.id == price.ingredientId }) { return false }
        if profile.allergyRefs.contains(where: { $0.kind == .ingredient && $0.id == price.ingredientId }) { return false }
        for allergen in profile.allergies {
            let state = price.allergenFlags[allergen.rawValue] ?? price.allergenFlags[allergen.databaseId]
            if state == "contains" || state == "may_contain" || state == "mayContain" { return false }
        }
        let flags: [DietPreference: String] = [
            .vegetarian: "vegetarian", .vegan: "vegan", .pescatarian: "pescatarian",
            .keto: "keto", .lowCarb: "low_carb", .highProtein: "high_protein",
            .glutenFree: "gluten_free", .dairyFree: "dairy_free", .lactoseFree: "lactose_free",
            .halal: "halal", .kosher: "kosher",
        ]
        for diet in profile.diets where diet.isStrict {
            if let key = flags[diet], price.dietaryFlags[key] != "yes" { return false }
        }
        return true
    }

    /// Replaces development fixtures with the current, food-only weekly flyer feed.
    /// A valid location with no coverage intentionally returns no deals instead of showing another region.
    /// Loads this week's food deals for the user's area. A new US / Canada area is fetched once (~40 s):
    /// the app stays usable and the Deals tab shows a "checking deals near you" banner meanwhile.
    /// A newer load (location changed) always wins over an older one.
    func loadLiveDeals() async {
        dealLoadID += 1
        let loadID = dealLoadID
        checkingStartedAt = .now
        let slow = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled, loadID == dealLoadID { checkingNewArea = true }
        }
        defer {
            slow.cancel()
            if loadID == dealLoadID { checkingNewArea = false }
        }
        do {
            var fetched = try await SupabaseService.shared.fetchActiveDeals(location: data.profile.location)
            // A new area can still be loading on the server: check again every 10 s for up to 2 minutes,
            // so deals appear by themselves without reopening the app.
            var tries = 0
            while fetched.isEmpty, data.profile.location.isSet, tries < 12, loadID == dealLoadID, !Task.isCancelled {
                tries += 1
                checkingNewArea = true
                try? await Task.sleep(for: .seconds(10))
                guard loadID == dealLoadID else { return }
                fetched = (try? await SupabaseService.shared.fetchActiveDeals(location: data.profile.location)) ?? []
            }
            guard loadID == dealLoadID else { return }
            availableDeals = fetched
            liveDealsLoaded = true
            lastDealsLoadAt = .now
            dealLoadError = nil
            refreshDeals()
        } catch {
            guard loadID == dealLoadID else { return }
            dealLoadError = error.localizedDescription
            // Never show sample prices to real users: keep the last live deals, or none.
            if !liveDealsLoaded {
                availableDeals = []
                refreshDeals()
            }
            analytics.track("live_deals_load_failed", ["error": error.localizedDescription])
        }
    }

    /// Weekly flyers change on different days (Tuesday, Thursday, two-week flyers...). Coming back to the app
    /// after an hour reloads deals and prices, so only this week's real offers are ever shown.
    func refreshDealsIfStale() async {
        guard Date.now.timeIntervalSince(lastDealsLoadAt) > 3600 else { refreshDeals(); return }
        await loadLiveDeals()
        await loadCurrentPrices()
    }

    func loadCurrentPrices() async {
        do {
            availableStorePrices = try await SupabaseService.shared.fetchCurrentPrices(location: data.profile.location)
            currentPricesLoaded = true
            currentPriceLoadError = nil
            refreshDeals()
        } catch {
            currentPriceLoadError = error.localizedDescription
            if !currentPricesLoaded { availableStorePrices = [] }
            refreshDeals()
            analytics.track("current_prices_load_failed", ["error": error.localizedDescription])
        }
    }

    func deals(myStoresOnly: Bool) -> [Deal] {
        guard myStoresOnly, !myStoreIds.isEmpty else { return deals }
        return deals.filter { myStoreIds.contains($0.retailerId) }
    }

    func storePrices(myStoresOnly: Bool) -> [StorePrice] {
        guard myStoresOnly, !myStoreIds.isEmpty else { return currentStorePrices }
        return currentStorePrices.filter { myStoreIds.contains($0.retailerId) }
    }

    func price(for recipe: Recipe, servings: Int? = nil) -> RecipePrice {
        if servings == nil || servings == recipe.servings, let cached = prices[recipe.id] { return cached }
        return pricing.price(recipe: recipe, servings: servings ?? recipe.servings,
                             deals: pricingDeals, currentPrices: pricingStorePrices)
    }

    private var pricingDeals: [Deal] {
        myStoreIds.isEmpty ? deals : deals.filter { myStoreIds.contains($0.retailerId) }
    }

    private var pricingStorePrices: [StorePrice] {
        myStoreIds.isEmpty ? currentStorePrices : currentStorePrices.filter { myStoreIds.contains($0.retailerId) }
    }

    private func refreshRanking() {
        let scoped = pricingDeals
        prices = Dictionary(uniqueKeysWithValues: recipes.map {
            ($0.id, pricing.price(recipe: $0, servings: $0.servings, deals: scoped, currentPrices: pricingStorePrices))
        })
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
        if direction == .like {
            like(item.recipe)
            markActive()
        }
        refreshRanking()
        track(direction == .like ? "recipe_swiped_right" : "recipe_swiped_left", ["recipe": item.id])
    }

    func restartDiscovery() {
        mutate { $0.queueResetDate = .now }
    }

    // MARK: Likes (swipe right) vs Saved (kept on purpose)

    var likedIds: [String] { data.likedIds ?? [] }

    func isLiked(_ recipe: Recipe) -> Bool {
        likedIds.contains(recipe.id)
    }

    /// Liked from Discover, not yet kept in Saved.
    var unsavedLikes: [Recipe] {
        let savedIds = Set(activeSaved.map(\.recipeId))
        return likedIds.compactMap { id in
            guard !savedIds.contains(id) else { return nil }
            return recipes.first { $0.id == id }
        }
    }

    func like(_ recipe: Recipe) {
        mutate { d in
            var ids = d.likedIds ?? []
            if !ids.contains(recipe.id) { ids.insert(recipe.id, at: 0) }
            d.likedIds = ids
        }
        track("recipe_liked", ["recipe": recipe.id])
    }

    func unlike(_ recipe: Recipe) {
        mutate { d in
            d.likedIds = (d.likedIds ?? []).filter { $0 != recipe.id }
        }
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

    func isInPantry(ingredientId: String) -> Bool {
        let name = IngredientCatalog.name(ingredientId)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let plain = ingredientId.replacingOccurrences(of: "_", with: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return data.pantry.contains { item in
            let stored = item.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            guard stored.count > 2 else { return false }
            return stored == name || stored == plain || (stored.count >= 4 && (name.contains(stored) || plain.contains(stored)))
        }
    }

    func addToGrocery(_ recipe: Recipe, servings: Int, includingPantry: Bool = true) {
        let p = price(for: recipe, servings: servings)
        let lines = p.lines.filter { includingPantry || !isInPantry(ingredientId: $0.ingredientId) }
        var addedDeal = false
        mutate { d in
            for line in lines {
                if let idx = d.grocery.firstIndex(where: { $0.ingredientId == line.ingredientId && $0.unit == line.unit && !$0.isChecked }) {
                    d.grocery[idx].quantity += line.quantity
                    if let cost = line.cost {
                        d.grocery[idx].estimatedCost = (d.grocery[idx].estimatedCost ?? 0) + cost
                    }
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

    func latestCook(_ recipe: Recipe) -> CookLog? {
        data.cookLogs.last { $0.recipeId == recipe.id }
    }

    func cookedToday(_ recipe: Recipe) -> Bool {
        guard let log = latestCook(recipe) else { return false }
        return Calendar.current.isDateInToday(log.date)
    }

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
        // Only the days of the current streak are checked: once a streak breaks, older days are cleared.
        let streak = wiseStreakDays
        let anchor = days.contains(dayKey(.now)) ? Date.now : (cal.date(byAdding: .day, value: -1, to: .now) ?? .now)
        let streakStart = cal.startOfDay(for: cal.date(byAdding: .day, value: -(max(streak, 1) - 1), to: anchor) ?? anchor)
        return (0..<7).map { i in
            let date = cal.date(byAdding: .day, value: i, to: start) ?? start
            let inStreak = streak > 0 && cal.startOfDay(for: date) >= streakStart
            return (symbols[i], inStreak && days.contains(dayKey(date)), cal.isDateInToday(date))
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

    func zestyAllowance() async throws -> ZestyAllowance {
        try await zesty.allowance()
    }

    func ask(_ query: String, conversationId: String?) async throws -> ZestyAskResponse {
        let response = try await zesty.ask(
            message: query,
            conversationId: conversationId,
            data: data,
            recipes: recipes,
            acceptedStoreIds: myStoreIds,
            blockedStoreIds: blockedStoreIds
        )
        track("ask_query_sent", ["model": response.model])
        return response
    }

    // MARK: - Recipe Lookup

    func recipe(id: String) -> Recipe? {
        recipes.first { $0.id == id }
    }

    // MARK: - Meal Planning

    func addToMealPlan(recipeId: String, date: Date, slot: MealSlot) {
        mutate { data in
            // Remove existing entry for same date/slot
            data.mealPlan.removeAll {
                Calendar.current.isDate($0.date, inSameDayAs: date) && $0.mealType == slot
            }
            data.mealPlan.append(MealPlanEntry(recipeId: recipeId, date: date, mealType: slot))
        }
    }

    func removeMealPlanEntry(_ id: UUID) {
        mutate { data in
            data.mealPlan.removeAll { $0.id == id }
        }
    }

    func markMealEaten(_ id: UUID) {
        mutate { data in
            guard let idx = data.mealPlan.firstIndex(where: { $0.id == id }) else { return }
            data.mealPlan[idx].isEaten.toggle()
            data.mealPlan[idx].eatenAt = data.mealPlan[idx].isEaten ? Date() : nil
        }
    }

    /// Marks a planned meal eaten and counts its savings once for that day.
    func eatMeal(_ id: UUID) {
        guard let entry = data.mealPlan.first(where: { $0.id == id }), !entry.isEaten else { return }
        guard let recipe = recipe(id: entry.recipeId) else { return }
        let cal = Calendar.current
        let already = data.cookLogs.contains { $0.recipeId == recipe.id && cal.isDate($0.date, inSameDayAs: entry.date) }
        let priced = price(for: recipe)
        mutate { d in
            if let idx = d.mealPlan.firstIndex(where: { $0.id == id }) {
                d.mealPlan[idx].isEaten = true
                d.mealPlan[idx].eatenAt = .now
                d.mealPlan[idx].savings = priced.savings
            }
            if !already {
                d.cookLogs.append(CookLog(recipeId: recipe.id, date: entry.date, madeWithDeal: priced.dealCount > 0, savings: priced.savings))
            }
        }
    }

    /// Past planned meals count as eaten. Their savings land on the day they were planned.
    func settlePastMeals() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let due = data.mealPlan.filter { cal.startOfDay(for: $0.date) < today && !$0.isEaten }
        guard !due.isEmpty else { return }
        var logs: [CookLog] = []
        for entry in due {
            guard let recipe = recipe(id: entry.recipeId) else { continue }
            let already = data.cookLogs.contains { $0.recipeId == recipe.id && cal.isDate($0.date, inSameDayAs: entry.date) }
            if already { continue }
            let priced = price(for: recipe)
            logs.append(CookLog(recipeId: recipe.id, date: entry.date, madeWithDeal: priced.dealCount > 0, savings: priced.savings))
        }
        let ids = Set(due.map(\.id))
        mutate { d in
            for idx in d.mealPlan.indices where ids.contains(d.mealPlan[idx].id) {
                d.mealPlan[idx].isEaten = true
                d.mealPlan[idx].eatenAt = d.mealPlan[idx].date
            }
            d.cookLogs.append(contentsOf: logs)
        }
    }

    func undoCookToday(_ recipe: Recipe) {
        mutate { d in
            if let idx = d.cookLogs.lastIndex(where: { $0.recipeId == recipe.id && Calendar.current.isDateInToday($0.date) }) {
                d.cookLogs.remove(at: idx)
            }
        }
    }

    func generateGroceryFromMealPlan(weekDates: [Date]) {
        let entries = data.mealPlan.filter { entry in
            weekDates.contains { Calendar.current.isDate($0, inSameDayAs: entry.date) }
        }
        for entry in entries {
            if let recipe = recipe(id: entry.recipeId) {
                addToGrocery(recipe, servings: 1, includingPantry: false)
            }
        }
    }

    // MARK: - Pantry

    func addPantryItem(_ item: PantryItem) {
        mutate { data in
            data.pantry.append(item)
        }
    }

    func removePantryItem(_ id: UUID) {
        mutate { data in
            data.pantry.removeAll { $0.id == id }
        }
    }
}
