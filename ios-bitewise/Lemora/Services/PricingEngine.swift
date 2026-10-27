import Foundation

nonisolated struct PriceLine: Identifiable, Sendable {
    var id: String { ingredientId }
    let ingredientId: String
    let quantity: Double
    let unit: IngredientUnit
    let regularCost: Double?
    let cost: Double?
    let deal: Deal?

    var savings: Double { max(0, (regularCost ?? 0) - (cost ?? regularCost ?? 0)) }
}

nonisolated struct RecipePrice: Sendable {
    let lines: [PriceLine]
    let servings: Int

    var total: Double? {
        guard lines.allSatisfy({ $0.cost != nil }) else { return nil }
        return lines.compactMap(\.cost).reduce(0, +)
    }
    var regularTotal: Double? {
        guard lines.allSatisfy({ $0.regularCost != nil }) else { return nil }
        return lines.compactMap(\.regularCost).reduce(0, +)
    }
    var savings: Double {
        guard let regularTotal, let total else { return 0 }
        return max(0, regularTotal - total)
    }
    var perServing: Double? { total.map { servings > 0 ? $0 / Double(servings) : $0 } }
    /// A provider-declared promotion still counts when its regular price is not
    /// published. Savings remain zero until a trustworthy baseline is available.
    var dealLines: [PriceLine] { lines.filter { $0.deal != nil } }
    var dealCount: Int { dealLines.count }
    var ingredientCount: Int { lines.count }
    var dealCoverage: Double {
        ingredientCount > 0 ? Double(dealCount) / Double(ingredientCount) : 0
    }
    var usesSampleData: Bool { lines.contains { $0.deal?.isSampleData == true } }
    var savingsFraction: Double {
        guard let regularTotal, regularTotal > 0 else { return 0 }
        return savings / regularTotal
    }

    /// A weekly-value score based on actual economics, not on whether the recipe was
    /// saved or previously swiped. Multiple discounted ingredients therefore matter.
    var weeklyValueScore: Double {
        let affordability = perServing.map { max(0, min(1, 1 - $0 / 12)) } ?? 0.5
        return savingsFraction * 0.50 + dealCoverage * 0.30 + affordability * 0.20
    }

    /// The single deal that saves the most, used for "Chicken is on sale at Maxi".
    var headlineDeal: PriceLine? { dealLines.max { $0.savings < $1.savings } }
}

/// Estimates recipe cost from ingredient quantities and current deals.
/// Unit-priced flyers are converted to the recipe quantity; the recipe's existing
/// estimated cost remains the conservative baseline when no regular price is supplied.
nonisolated struct PricingEngine {
    func price(recipe: Recipe, servings: Int, deals: [Deal], currentPrices: [StorePrice] = []) -> RecipePrice {
        let scale = Double(max(1, servings)) / Double(max(1, recipe.servings))
        let byIngredient = Dictionary(grouping: deals, by: \.ingredientId)
        let pricesByIngredient = Dictionary(grouping: currentPrices, by: \.ingredientId)
        let lines = recipe.ingredients.map { item -> PriceLine in
            let compatibleIds = Self.compatibleDealIds(for: item.ingredientId)
            let gramsPerUnit = IngredientMatch.gramsPerUnit[item.ingredientId]
            // Cost follows what is bought, which doesn't always shrink with the portions (fixed costs).
            let bought = item.quantity * Self.purchaseScale(for: item, scale: scale)
            let observedCosts = compatibleIds.flatMap { pricesByIngredient[$0] ?? [] }.filter { !$0.isDiscounted }.compactMap {
                $0.cost(for: bought, unit: item.unit)
            }
            let regular = observedCosts.min() ?? item.estimatedCost.map { $0 * Self.purchaseScale(for: item, scale: scale) }
            let candidates = compatibleIds.flatMap { byIngredient[$0] ?? [] }.compactMap { deal -> (Deal, Double)? in
                guard let converted = deal.cost(for: bought, unit: item.unit, gramsPerUnit: gramsPerUnit) else {
                    // Percentage-based fallback is used only when the provider supplied a discount.
                    guard deal.discountPercent != nil else { return nil }
                    guard let regular else { return nil }
                    return (deal, regular * deal.priceRatio)
                }
                return (deal, converted)
            }
            let best = candidates.min { $0.1 < $1.1 }
            let discounted = best.map { candidate in regular.map { min($0, candidate.1) } ?? candidate.1 } ?? regular
            let appliedDeal: Deal? = best.flatMap { candidate in
                guard regular == nil || candidate.1 < regular! else { return nil }
                return candidate.0
            }
            return PriceLine(ingredientId: item.ingredientId, quantity: item.quantity * scale, unit: item.unit,
                             regularCost: regular, cost: discounted, deal: appliedDeal)
        }
        return RecipePrice(lines: lines, servings: max(1, servings))
    }

    /// Share of an ingredient you still pay for when cooking fewer portions than the recipe makes.
    /// Cooking alone isn't a quarter of the price: a pack of chicken, a can, a bunch of herbs or a whole
    /// onion is bought whole. Spices and oils last many meals, so they shrink almost fully.
    /// Cooking more portions than the recipe stays linear.
    static func purchaseScale(for item: RecipeIngredient, scale: Double) -> Double {
        guard scale < 1 else { return scale }
        let category = IngredientCatalog.ingredient(item.ingredientId)?.category
            ?? CatalogIngredientInfo.info[item.ingredientId]?.category
            ?? .other
        let fixed: Double
        switch item.unit {
        case .tsp, .tbsp, .clove:
            fixed = 0.15
        case .can:
            fixed = 1
        case .unit:
            // Whole items: round up to what you actually buy.
            guard item.quantity > 0 else { return scale }
            let needed = (item.quantity * scale).rounded(.up)
            return min(1, max(scale, needed / item.quantity))
        default:
            switch category {
            case .protein, .dairy: fixed = 0.4
            case .produce: fixed = 0.35
            case .bakery: fixed = 0.5
            case .frozen: fixed = 0.2
            case .pantry: fixed = 0.1
            default: fixed = 0.3
            }
        }
        return fixed + (1 - fixed) * scale
    }

    /// Strict: only deals for the same food count (see IngredientMatch). Near-identical swaps are suggested by Zesty instead.
    static func compatibleDealIds(for ingredientId: String) -> [String] {
        IngredientMatch.dealKeys(for: ingredientId)
    }

    static func recipeIngredient(_ recipeIngredientId: String, matches dealIngredientId: String) -> Bool {
        compatibleDealIds(for: recipeIngredientId).contains(dealIngredientId)
    }
}
