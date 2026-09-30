import Foundation

nonisolated struct AskResponse: Sendable {
    let message: String
    let results: [ScoredRecipe]
}

/// On-device meal search that understands budget, protein, diet, time, cuisine, store and pantry
/// constraints. Candidates are already hard-filtered for the user's allergies and diets, so
/// results can never violate a restriction. A hosted LLM can later sit in front of this
/// as a query parser without changing the safety guarantees.
nonisolated struct AskEngine {
    private static let ingredientAliases: [String: [String]] = [
        "chicken_breast": ["chicken", "poulet"],
        "flank_steak": ["beef", "steak", "boeuf"],
        "salmon": ["salmon", "fish", "saumon"],
        "eggs": ["egg", "eggs", "oeuf"],
        "rice": ["rice", "riz"],
        "chickpeas": ["chickpea", "chickpeas"],
        "lentils": ["lentil", "lentils"],
        "rigatoni": ["pasta", "rigatoni"],
        "avocado": ["avocado"],
        "sweet_potato": ["sweet potato"],
        "greek_yogurt": ["yogurt"],
        "broccoli": ["broccoli"],
        "cauliflower": ["cauliflower"],
        "blueberries": ["blueberry", "blueberries"],
        "bell_pepper": ["pepper", "peppers"],
    ]

    func answer(_ query: String, candidates: [ScoredRecipe], profile: UserProfile) -> AskResponse {
        let q = query.lowercased()
        var notes: [String] = []
        var pool = candidates

        if let maxPrice = firstNumber(in: q, after: ["under $", "under ", "below $", "below ", "less than $", "max $"]) {
            pool = pool.filter { $0.price.perServing <= maxPrice }
            notes.append(String(localized: "under \(Money.format(maxPrice)) per serving"))
        }

        if let minProtein = firstNumber(in: q, pattern: #"(\d+)\s?g\s?(of\s)?protein"#) {
            pool = pool.filter { Double($0.recipe.nutrition.protein) >= minProtein }
            notes.append(String(localized: "\(Int(minProtein))g+ protein"))
        } else if q.contains("high protein") || q.contains("high-protein") || q.contains("protein") {
            pool = pool.filter { $0.recipe.nutrition.protein >= 35 }
            notes.append(String(localized: "high protein"))
        }

        if q.contains("vegan") {
            pool = pool.filter { item in
                item.recipe.ingredients.allSatisfy { IngredientCatalog.ingredient($0.ingredientId)?.animal == AnimalKind.none }
            }
            notes.append(String(localized: "vegan"))
        } else if q.contains("vegetarian") || q.contains("veggie") || q.contains("meatless") {
            pool = pool.filter { item in
                item.recipe.ingredients.allSatisfy {
                    let a = IngredientCatalog.ingredient($0.ingredientId)?.animal ?? .none
                    return ![.meat, .pork, .poultry, .fish, .shellfish].contains(a)
                }
            }
            notes.append(String(localized: "vegetarian"))
        }

        if q.contains("spicy") {
            pool = pool.filter { $0.recipe.tags.contains(.spicy) || [.mexican, .indian, .thai].contains($0.recipe.cuisine) }
            notes.append(String(localized: "with some heat"))
        }
        if q.contains("quick") || q.contains("fast") || q.contains("15 min") || q.contains("20 min") {
            pool = pool.filter { $0.recipe.totalMinutes <= 25 }
            notes.append(String(localized: "quick"))
        }
        if q.contains("meal prep") || q.contains("meal-prep") {
            pool = pool.filter { $0.recipe.tags.contains(.mealPrep) }
            notes.append(String(localized: "meal-prep friendly"))
        }
        for meal in [MealType.breakfast, .lunch, .dinner] where q.contains(meal.rawValue) {
            if meal == .breakfast { pool = pool.filter { $0.recipe.mealType == .breakfast } }
            else { pool = pool.filter { $0.recipe.mealType != .breakfast } }
        }
        for cuisine in Cuisine.allCases where q.contains(cuisine.title.lowercased()) {
            pool = pool.filter { $0.recipe.cuisine == cuisine }
            notes.append(cuisine.title)
        }

        if let store = RetailerCatalog.all.first(where: { q.contains($0.name.lowercased()) }) {
            pool = pool.filter { $0.price.dealLines.contains { $0.deal?.retailerId == store.id } }
            notes.append(String(localized: "using \(store.name) deals"))
        } else if q.contains("deal") || q.contains("sale") || q.contains("cheap") {
            pool.sort { $0.price.perServing < $1.price.perServing }
        }

        let mentioned = Self.ingredientAliases.filter { _, aliases in aliases.contains { q.contains($0) } }.map(\.key)
        if !mentioned.isEmpty {
            let pantryMode = q.contains("i have") || q.contains("what can i make") || q.contains("using")
            pool = pool
                .map { item -> (ScoredRecipe, Int) in
                    let ids = Set(item.recipe.ingredients.map(\.ingredientId))
                    return (item, mentioned.filter { ids.contains($0) }.count)
                }
                .filter { pantryMode ? $0.1 > 0 : $0.1 == mentioned.count }
                .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.score > $1.0.score }
                .map(\.0)
            notes.append(String(localized: "with \(mentioned.map { IngredientCatalog.name($0).lowercased() }.joined(separator: ", "))"))
        }

        let top = Array(pool.prefix(4))
        let constraint = notes.isEmpty ? "" : " " + notes.joined(separator: ", ")
        if top.isEmpty {
            return AskResponse(message: String(localized: "I couldn't find a meal\(constraint) that also fits your profile yet. Try loosening one constraint, like the price or protein target."), results: [])
        }
        var message = top.count == 1
            ? String(localized: "Here's a great match\(constraint).")
            : String(localized: "Here are \(top.count) meals\(constraint).")
        if !profile.allergies.isEmpty {
            message += " " + String(localized: "All of them avoid your allergens.")
        }
        return AskResponse(message: message, results: top)
    }

    private func firstNumber(in text: String, after prefixes: [String]) -> Double? {
        for prefix in prefixes {
            guard let range = text.range(of: prefix) else { continue }
            let tail = text[range.upperBound...]
            let digits = tail.prefix { $0.isNumber || $0 == "." }
            if let value = Double(digits), value > 0 { return value }
        }
        return nil
    }

    private func firstNumber(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[r])
    }
}
