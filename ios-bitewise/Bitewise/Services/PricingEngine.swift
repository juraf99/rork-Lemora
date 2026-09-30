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
    var usesSampleData: Bool { lines.contains { $0.deal?.isSampleData == true } }
    var savingsFraction: Double { regularTotal > 0 ? savings / regularTotal : 0 }

    /// The single deal that saves the most, used for "Chicken is on sale at Maxi".
    var headlineDeal: PriceLine? { dealLines.max { $0.savings < $1.savings } }
}

/// Estimates recipe cost from ingredient quantities and current deals.
/// Only deals with a real regular price reduce the estimate — no fabricated discounts.
nonisolated struct PricingEngine {
    func price(recipe: Recipe, servings: Int, deals: [Deal]) -> RecipePrice {
        let scale = Double(max(1, servings)) / Double(max(1, recipe.servings))
        let byIngredient = Dictionary(grouping: deals.filter { $0.regularPrice != nil }, by: \.ingredientId)
        let lines = recipe.ingredients.map { item -> PriceLine in
            let regular = item.estimatedCost * scale
            let best = byIngredient[item.ingredientId]?.min { $0.priceRatio < $1.priceRatio }
            let cost = best.map { regular * $0.priceRatio } ?? regular
            return PriceLine(ingredientId: item.ingredientId, quantity: item.quantity * scale, unit: item.unit,
                             regularCost: regular, cost: cost, deal: best)
        }
        return RecipePrice(lines: lines, servings: max(1, servings))
    }
}
