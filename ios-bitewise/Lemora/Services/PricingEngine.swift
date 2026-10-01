import Foundation

nonisolated struct PriceLine: Identifiable, Sendable {
    var id: String { ingredientId }
    let ingredientId: String
    let quantity: Double
    let unit: IngredientUnit
    let regularCost: Double
    let cost: Double
    let deal: Deal?

    var savings: Double { max(0, regularCost - cost) }
}

nonisolated struct RecipePrice: Sendable {
    let lines: [PriceLine]
    let servings: Int

    var total: Double { lines.reduce(0) { $0 + $1.cost } }
    var regularTotal: Double { lines.reduce(0) { $0 + $1.regularCost } }
    var savings: Double { max(0, regularTotal - total) }
    var perServing: Double { servings > 0 ? total / Double(servings) : total }
    var dealLines: [PriceLine] { lines.filter { $0.deal != nil && $0.savings > 0.01 } }
    var dealCount: Int { dealLines.count }
    var ingredientCount: Int { lines.count }
    var dealCoverage: Double {
        ingredientCount > 0 ? Double(dealCount) / Double(ingredientCount) : 0
    }
    var usesSampleData: Bool { lines.contains { $0.deal?.isSampleData == true } }
    var savingsFraction: Double { regularTotal > 0 ? savings / regularTotal : 0 }

    /// A weekly-value score based on actual economics, not on whether the recipe was
    /// saved or previously swiped. Multiple discounted ingredients therefore matter.
    var weeklyValueScore: Double {
        let affordability = max(0, min(1, 1 - perServing / 12))
        return savingsFraction * 0.50 + dealCoverage * 0.30 + affordability * 0.20
    }

    /// The single deal that saves the most, used for "Chicken is on sale at Maxi".
    var headlineDeal: PriceLine? { dealLines.max { $0.savings < $1.savings } }
}

/// Estimates recipe cost from ingredient quantities and current deals.
/// Unit-priced flyers are converted to the recipe quantity; the recipe's existing
/// estimated cost remains the conservative baseline when no regular price is supplied.
nonisolated struct PricingEngine {
    func price(recipe: Recipe, servings: Int, deals: [Deal]) -> RecipePrice {
        let scale = Double(max(1, servings)) / Double(max(1, recipe.servings))
        let byIngredient = Dictionary(grouping: deals, by: \.ingredientId)
        let lines = recipe.ingredients.map { item -> PriceLine in
            let regular = item.estimatedCost * scale
            let compatibleIds = Self.compatibleDealIds(for: item.ingredientId)
            let candidates = compatibleIds.flatMap { byIngredient[$0] ?? [] }.compactMap { deal -> (Deal, Double)? in
                guard let converted = deal.cost(for: item.quantity * scale, unit: item.unit) else {
                    // Percentage-based fallback is used only when the provider supplied a discount.
                    guard deal.discountPercent != nil else { return nil }
                    return (deal, regular * deal.priceRatio)
                }
                return (deal, converted)
            }
            let best = candidates.min { $0.1 < $1.1 }
            let discounted = best.map { min(regular, $0.1) } ?? regular
            let appliedDeal = best.flatMap { $0.1 < regular ? $0.0 : nil }
            return PriceLine(ingredientId: item.ingredientId, quantity: item.quantity * scale, unit: item.unit,
                             regularCost: regular, cost: discounted, deal: appliedDeal)
        }
        return RecipePrice(lines: lines, servings: max(1, servings))
    }

    static func compatibleDealIds(for ingredientId: String) -> [String] {
        switch ingredientId {
        case "chicken_breast": ["chicken_breast", "chicken"]
        case "flank_steak": ["flank_steak", "beef"]
        case "eggs": ["eggs", "egg"]
        case "greek_yogurt": ["greek_yogurt", "greek_yogurt_or_skyr", "yogurt"]
        case "rigatoni": ["rigatoni", "pasta"]
        case "sweet_potato": ["sweet_potato", "potato"]
        case "bell_pepper": ["bell_pepper", "pepper", "peppers"]
        default: [ingredientId]
        }
    }

    static func recipeIngredient(_ recipeIngredientId: String, matches dealIngredientId: String) -> Bool {
        compatibleDealIds(for: recipeIngredientId).contains(dealIngredientId)
    }
}
