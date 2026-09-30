import Foundation

nonisolated enum IngredientUnit: String, Codable, Sendable {
    case g, ml, unit, tbsp, tsp, cup, can, clove

    func format(_ quantity: Double) -> String {
        let q = quantity.rounded(toPlaces: quantity < 10 ? 1 : 0)
        let number = q.formatted(.number.precision(.fractionLength(0...1)))
        switch self {
        case .g:
            if quantity >= 1000 { return "\((quantity / 1000).formatted(.number.precision(.fractionLength(0...1)))) kg" }
            return "\(number) g"
        case .ml:
            if quantity >= 1000 { return "\((quantity / 1000).formatted(.number.precision(.fractionLength(0...1)))) L" }
            return "\(number) ml"
        case .unit: return number
        case .tbsp: return "\(number) tbsp"
        case .tsp: return "\(number) tsp"
        case .cup: return quantity == 1 ? "1 cup" : "\(number) cups"
        case .can: return quantity == 1 ? "1 can" : "\(number) cans"
        case .clove: return quantity == 1 ? "1 clove" : "\(number) cloves"
        }
    }
}

extension Double {
    nonisolated func rounded(toPlaces places: Int) -> Double {
        let m = pow(10, Double(places))
        return (self * m).rounded() / m
    }
}

nonisolated struct RecipeIngredient: Hashable, Sendable, Identifiable {
    var id: String { ingredientId }
    let ingredientId: String
    let rawText: String
    let quantity: Double
    let unit: IngredientUnit
    /// Estimated regular cost (CAD) of the quantity used. Development fixture value.
    let estimatedCost: Double
}

nonisolated enum NutritionStatus: String, Codable, Sendable {
    case verified, estimated, unknown
}

nonisolated struct Nutrition: Hashable, Sendable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let fiber: Int?
    let status: NutritionStatus
}

nonisolated enum RecipeTag: String, Codable, CaseIterable, Sendable {
    case highProtein, quick, mealPrep, budget, spicy, comfort, bowl, vegetarianFriendly

    var title: String {
        switch self {
        case .highProtein: String(localized: "High Protein")
        case .quick: String(localized: "Quick Meal")
        case .mealPrep: String(localized: "Meal Prep")
        case .budget: String(localized: "Budget Pick")
        case .spicy: String(localized: "Spicy")
        case .comfort: String(localized: "Comfort Food")
        case .bowl: String(localized: "Healthy Bowl")
        case .vegetarianFriendly: String(localized: "Veggie")
        }
    }
}

nonisolated enum RecipeSource: String, Codable, Sendable {
    case bitewiseOriginal, founderSubmitted, chefCollaboration, creatorCollaboration, external, generatedSuggestion

    var title: String {
        switch self {
        case .bitewiseOriginal: String(localized: "Lemora Original")
        case .founderSubmitted: String(localized: "Founder recipe")
        case .chefCollaboration: String(localized: "Chef collaboration")
        case .creatorCollaboration: String(localized: "Creator collaboration")
        case .external: String(localized: "External recipe")
        case .generatedSuggestion: String(localized: "Generated suggestion")
        }
    }
}

nonisolated struct Recipe: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let imageName: String
    let cuisine: Cuisine
    let mealType: MealType
    let mainProtein: String
    let servings: Int
    let prepMinutes: Int
    let cookMinutes: Int
    let ingredients: [RecipeIngredient]
    let steps: [String]
    let nutrition: Nutrition
    let tags: Set<RecipeTag>
    let source: RecipeSource

    var totalMinutes: Int { prepMinutes + cookMinutes }

    static func == (lhs: Recipe, rhs: Recipe) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
