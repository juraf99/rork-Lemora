import Foundation

nonisolated enum ReasonCode: String, Codable, Sendable {
    case likedSimilar = "LIKED_SIMILAR_RECIPES"
    case highProteinGoal = "HIGH_PROTEIN_GOAL"
    case lightMealGoal = "LIGHT_MEAL_GOAL"
    case highFiber = "HIGH_FIBER"
    case currentDeal = "CURRENT_DEAL"
    case fitsBudget = "FITS_WEEKLY_BUDGET"
    case favoriteCuisine = "FAVORITE_CUISINE"
    case quickMeal = "QUICK_MEAL"
    case lowCost = "LOW_COST_PER_SERVING"
    case newDiscovery = "NEW_DISCOVERY"
}

nonisolated struct RecommendationReason: Hashable, Sendable {
    let code: ReasonCode
    let text: String
}

nonisolated struct ScoredRecipe: Identifiable, Sendable {
    var id: String { recipe.id }
    let recipe: Recipe
    let score: Double
    let matchPercent: Int
    let reasons: [RecommendationReason]
    let price: RecipePrice

    var primaryReason: RecommendationReason? {
        reasons.first { $0.code == .currentDeal } ?? reasons.first
    }
}

/// Recommendation pipeline v1:
/// hard safety filters -> goal fit -> taste -> price/value -> convenience -> novelty.
/// Safety filters can never be outweighed by scoring.
nonisolated struct RecommendationEngine {
    static let version = "recommendation_engine_v1"

    // MARK: Hard filters

    /// Returns a human-readable reason when the recipe must be excluded for this user.
    func exclusionReason(for recipe: Recipe, profile: UserProfile) -> String? {
        let ingredients = recipe.ingredients.compactMap { IngredientCatalog.ingredient($0.ingredientId) }

        for allergen in profile.allergies {
            if ingredients.contains(where: { $0.contains.contains(allergen) }) { return "Contains \(allergen.title)" }
            if ingredients.contains(where: { $0.mayContain.contains(allergen) }) { return "May contain \(allergen.title)" }
        }

        let searchable = recipe.ingredients.map { ($0.rawText + " " + IngredientCatalog.name($0.ingredientId)).lowercased() }
        for allergy in profile.allergyRefs where allergy.kind == .ingredient {
            let term = allergy.name.trimmingCharacters(in: .whitespaces).lowercased()
            let exactIngredient = recipe.ingredients.contains { $0.ingredientId == allergy.id }
            if exactIngredient || (!term.isEmpty && searchable.contains(where: { $0.contains(term) })) {
                return "Contains \(allergy.name)"
            }
        }

        for dislike in profile.dislikedIngredients {
            let term = dislike.name.trimmingCharacters(in: .whitespaces).lowercased()
            let exactIngredient = recipe.ingredients.contains { $0.ingredientId == dislike.id }
            if exactIngredient || (!term.isEmpty && searchable.contains(where: { $0.contains(term) })) {
                return "Includes \(dislike.name)"
            }
        }

        let animals = Set(ingredients.map(\.animal))
        let hasAllergen: (Allergen) -> Bool = { a in ingredients.contains { $0.contains.contains(a) || $0.mayContain.contains(a) } }
        for diet in profile.diets where diet.isStrict {
            switch diet {
            case .vegetarian:
                if !animals.isDisjoint(with: [.meat, .pork, .poultry, .fish, .shellfish]) { return "Not vegetarian" }
            case .vegan:
                if !animals.isSubset(of: [.none]) { return "Not vegan" }
            case .pescatarian:
                if !animals.isDisjoint(with: [.meat, .pork, .poultry]) { return "Not pescatarian" }
            case .glutenFree:
                if hasAllergen(.wheat) { return "May contain gluten" }
            case .dairyFree, .lactoseFree:
                if hasAllergen(.milk) { return "Contains dairy" }
            case .keto:
                if recipe.nutrition.carbs > 25 { return "Too many carbs for keto" }
            case .halal:
                if animals.contains(.pork) { return "Not halal" }
            case .kosher:
                if animals.contains(.pork) || animals.contains(.shellfish) { return "Not kosher" }
            default:
                break
            }
        }
        return nil
    }

    func passesHardFilters(_ recipe: Recipe, profile: UserProfile) -> Bool {
        exclusionReason(for: recipe, profile: profile) == nil
            && (profile.mealTypes.isEmpty || profile.mealTypes.contains(recipe.mealType))
    }

    // MARK: Taste

    static func tasteKeys(for recipe: Recipe) -> [String] {
        var keys = ["cuisine:\(recipe.cuisine.rawValue)", "protein:\(recipe.mainProtein)", "meal:\(recipe.mealType.rawValue)"]
        keys += recipe.tags.map { "tag:\($0.rawValue)" }
        return keys
    }

    /// Single swipes are weak signals: small increments, clamped.
    func learn(from recipe: Recipe, direction: SwipeDirection, weights: [String: Double]) -> [String: Double] {
        var updated = weights
        let delta = direction == .like ? 0.6 : -0.3
        for key in Self.tasteKeys(for: recipe) {
            updated[key] = min(4, max(-4, (updated[key] ?? 0) + delta))
        }
        return updated
    }

    // MARK: Ranking

    func rank(recipes: [Recipe], profile: UserProfile, taste: [String: Double], seen: Set<String>,
              prices: [String: RecipePrice], weights: RecommendationWeights) -> [ScoredRecipe] {
        recipes
            .filter { passesHardFilters($0, profile: profile) }
            .compactMap { recipe -> ScoredRecipe? in
                guard let price = prices[recipe.id] else { return nil }
                return score(recipe, price: price, profile: profile, taste: taste, seen: seen, weights: weights)
            }
            .sorted { $0.score > $1.score }
    }

    func score(_ recipe: Recipe, price: RecipePrice, profile: UserProfile, taste: [String: Double],
               seen: Set<String>, weights: RecommendationWeights) -> ScoredRecipe {
        var reasons: [RecommendationReason] = []
        let n = recipe.nutrition

        // Taste
        let keys = Self.tasteKeys(for: recipe)
        let tasteRaw = keys.reduce(0) { $0 + (taste[$1] ?? 0) } / Double(keys.count)
        let tasteScore = 0.5 + tanh(tasteRaw) / 2
        let hasLearned = taste.values.contains { $0 > 0.5 }
        if hasLearned && tasteRaw > 0.35 {
            reasons.append(.init(code: .likedSimilar, text: String(localized: "Because you liked similar meals")))
        }
        if profile.cuisines.contains(recipe.cuisine) {
            reasons.append(.init(code: .favoriteCuisine, text: String(localized: "You love \(recipe.cuisine.title) food")))
        }

        // Goal
        var goalScore = 0.6
        switch profile.goal {
        case .buildMuscle, .gainWeight:
            goalScore = n.protein >= 40 ? 1 : (n.protein >= 30 ? 0.7 : 0.3)
            if profile.goal == .gainWeight && n.calories >= 550 { goalScore = min(1, goalScore + 0.15) }
            if n.protein >= 40 { reasons.append(.init(code: .highProteinGoal, text: String(localized: "High protein for your goal"))) }
        case .loseWeight:
            goalScore = n.calories <= 500 ? 1 : (n.calories <= 600 ? 0.7 : 0.35)
            if n.protein >= 35 { goalScore = min(1, goalScore + 0.1) }
            if n.calories <= 500 { reasons.append(.init(code: .lightMealGoal, text: String(localized: "Lighter meal that still fills you up"))) }
        case .saveMoney:
            goalScore = price.perServing <= 3.5 ? 1 : (price.perServing <= 5 ? 0.7 : 0.4)
            if price.perServing <= 4 { reasons.append(.init(code: .lowCost, text: String(localized: "Low cost per serving"))) }
        case .eatHealthier:
            let fiber = n.fiber ?? 0
            goalScore = fiber >= 10 ? 1 : (fiber >= 6 ? 0.7 : 0.4)
            if fiber >= 10 { reasons.append(.init(code: .highFiber, text: String(localized: "Packed with fiber and veggies"))) }
        case .mealPrep:
            goalScore = recipe.tags.contains(.mealPrep) ? 1 : 0.45
            if recipe.tags.contains(.mealPrep) {
                reasons.append(.init(code: .quickMeal, text: String(localized: "Great for meal prep")))
            }
        case .maintain, .discover, .other:
            goalScore = 0.6
        }
        if profile.diets.contains(.highProtein) && n.protein >= 35 { goalScore = min(1, goalScore + 0.15) }
        if profile.diets.contains(.lowCarb) && n.carbs <= 40 { goalScore = min(1, goalScore + 0.15) }

        // Deals
        let dealScore = min(1, price.savingsFraction * 2.5)
        if let headline = price.headlineDeal, let deal = headline.deal {
            reasons.insert(.init(code: .currentDeal, text: String(localized: "\(IngredientCatalog.name(headline.ingredientId)) is on sale at \(deal.retailerDisplayName)")), at: 0)
        }

        // Budget
        var budgetScore = 0.6
        if let budget = profile.weeklyBudget, budget > 0 {
            let target = budget / Double(max(1, profile.householdSize) * 14)
            let ratio = price.perServing / target
            budgetScore = ratio <= 0.8 ? 1 : (ratio <= 1.1 ? 0.7 : 0.3)
            if ratio <= 1 { reasons.append(.init(code: .fitsBudget, text: String(localized: "Fits your weekly budget"))) }
        }

        // Convenience
        let timeScore = recipe.totalMinutes <= 20 ? 1 : (recipe.totalMinutes <= 30 ? 0.7 : 0.4)
        if recipe.totalMinutes <= 20 { reasons.append(.init(code: .quickMeal, text: String(localized: "Ready in \(recipe.totalMinutes) min"))) }

        // Novelty
        let isNew = !seen.contains(recipe.id)
        let noveltyScore = isNew ? 1 : 0.3
        if isNew && reasons.count < 2 { reasons.append(.init(code: .newDiscovery, text: String(localized: "Something new to try"))) }

        let w = weights
        let totalWeight = w.taste + w.goal + w.deal + w.budget + w.time + w.novelty
        let raw = (tasteScore * w.taste + goalScore * w.goal + dealScore * w.deal + budgetScore * w.budget
                   + timeScore * w.time + noveltyScore * w.novelty) / max(0.0001, totalWeight)
        let match = Int((55 + raw * 44).rounded())

        return ScoredRecipe(recipe: recipe, score: raw, matchPercent: min(99, max(50, match)), reasons: reasons, price: price)
    }

    // MARK: Diet compatibility (display)

    func compatibility(of recipe: Recipe) -> [(DietPreference, TriState)] {
        let ingredients = recipe.ingredients.compactMap { IngredientCatalog.ingredient($0.ingredientId) }
        let animals = Set(ingredients.map(\.animal))
        func allergenState(_ a: Allergen) -> TriState {
            if ingredients.contains(where: { $0.contains.contains(a) }) { return .no }
            if ingredients.contains(where: { $0.mayContain.contains(a) }) { return .uncertain }
            return .yes
        }
        let hasCertifiableMeat = !animals.isDisjoint(with: [.meat, .poultry])
        return [
            (.vegetarian, animals.isDisjoint(with: [.meat, .pork, .poultry, .fish, .shellfish]) ? .yes : .no),
            (.vegan, animals.isSubset(of: [.none]) ? .yes : .no),
            (.glutenFree, allergenState(.wheat)),
            (.dairyFree, allergenState(.milk)),
            (.highProtein, recipe.nutrition.protein >= 30 ? .yes : .no),
            (.halal, animals.contains(.pork) ? .no : (hasCertifiableMeat ? .uncertain : .yes)),
        ]
    }

    func allergens(of recipe: Recipe) -> (contains: [Allergen], mayContain: [Allergen]) {
        let ingredients = recipe.ingredients.compactMap { IngredientCatalog.ingredient($0.ingredientId) }
        let contains = Set(ingredients.flatMap(\.contains))
        let may = Set(ingredients.flatMap(\.mayContain)).subtracting(contains)
        return (Allergen.allCases.filter { contains.contains($0) }, Allergen.allCases.filter { may.contains($0) })
    }
}
