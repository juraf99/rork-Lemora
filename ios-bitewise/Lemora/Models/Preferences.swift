import Foundation

nonisolated enum TriState: String, Codable, Sendable {
    case yes, no, uncertain
}

nonisolated enum Goal: String, Codable, CaseIterable, Identifiable, Sendable {
    case saveMoney, loseWeight, buildMuscle, gainWeight, eatHealthier, maintain, discover, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveMoney: String(localized: "Save money on groceries")
        case .loseWeight: String(localized: "Lose weight")
        case .buildMuscle: String(localized: "Build muscle")
        case .gainWeight: String(localized: "Gain weight")
        case .eatHealthier: String(localized: "Eat healthier")
        case .maintain: String(localized: "Maintain my weight")
        case .discover: String(localized: "Discover better meals")
        case .other: String(localized: "Other")
        }
    }

    var symbol: String {
        switch self {
        case .saveMoney: "dollarsign.circle"
        case .loseWeight: "figure.walk"
        case .buildMuscle: "dumbbell"
        case .gainWeight: "chart.line.uptrend.xyaxis"
        case .eatHealthier: "leaf"
        case .maintain: "scalemass"
        case .discover: "sparkles"
        case .other: "ellipsis.circle"
        }
    }

    var needsBodyMetrics: Bool {
        self == .loseWeight || self == .buildMuscle || self == .gainWeight
    }
}

nonisolated enum DietPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case everything, vegetarian, vegan, pescatarian, keto, lowCarb, highProtein
    case glutenFree, dairyFree, lactoseFree, halal, kosher

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everything: String(localized: "I eat everything")
        case .vegetarian: String(localized: "Vegetarian")
        case .vegan: String(localized: "Vegan")
        case .pescatarian: String(localized: "Pescatarian")
        case .keto: String(localized: "Keto")
        case .lowCarb: String(localized: "Low carb")
        case .highProtein: String(localized: "High protein")
        case .glutenFree: String(localized: "Gluten-free")
        case .dairyFree: String(localized: "Dairy-free")
        case .lactoseFree: String(localized: "Lactose-free")
        case .halal: String(localized: "Halal")
        case .kosher: String(localized: "Kosher")
        }
    }

    /// Strict diets are hard filters. Soft ones only influence ranking.
    var isStrict: Bool {
        switch self {
        case .everything, .lowCarb, .highProtein: false
        default: true
        }
    }
}

nonisolated enum Allergen: String, Codable, CaseIterable, Identifiable, Sendable {
    case peanuts, treeNuts, milk, egg, fish, shellfish, soy, wheat, sesame

    var id: String { rawValue }

    var title: String {
        switch self {
        case .peanuts: String(localized: "Peanuts")
        case .treeNuts: String(localized: "Tree nuts")
        case .milk: String(localized: "Milk")
        case .egg: String(localized: "Egg")
        case .fish: String(localized: "Fish")
        case .shellfish: String(localized: "Shellfish")
        case .soy: String(localized: "Soy")
        case .wheat: String(localized: "Wheat")
        case .sesame: String(localized: "Sesame")
        }
    }
}

nonisolated enum Cuisine: String, Codable, CaseIterable, Identifiable, Sendable {
    case italian, mexican, japanese, korean, indian, greek, middleEastern
    case american, french, thai, vietnamese, caribbean, mediterranean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .italian: String(localized: "Italian")
        case .mexican: String(localized: "Mexican")
        case .japanese: String(localized: "Japanese")
        case .korean: String(localized: "Korean")
        case .indian: String(localized: "Indian")
        case .greek: String(localized: "Greek")
        case .middleEastern: String(localized: "Middle Eastern")
        case .american: String(localized: "American")
        case .french: String(localized: "French")
        case .thai: String(localized: "Thai")
        case .vietnamese: String(localized: "Vietnamese")
        case .caribbean: String(localized: "Caribbean")
        case .mediterranean: String(localized: "Mediterranean")
        }
    }
}

nonisolated enum MealType: String, Codable, Sendable {
    case breakfast, lunch, dinner
}

nonisolated enum ShoppingStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
    case convenience, balanced, maximumSavings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .convenience: String(localized: "Convenience")
        case .balanced: String(localized: "Balanced")
        case .maximumSavings: String(localized: "Maximum savings")
        }
    }

    var subtitle: String {
        switch self {
        case .convenience: String(localized: "One store whenever possible.")
        case .balanced: String(localized: "Another store only if the savings are worth it.")
        case .maximumSavings: String(localized: "Optimize across all the stores I accept.")
        }
    }

    var symbol: String {
        switch self {
        case .convenience: "bag"
        case .balanced: "scalemass"
        case .maximumSavings: "chart.bar.xaxis"
        }
    }
}

nonisolated enum StorePreference: String, Codable, Sendable {
    case preferred, acceptable, doNotRecommend

    var title: String {
        switch self {
        case .preferred: String(localized: "Preferred")
        case .acceptable: String(localized: "Acceptable")
        case .doNotRecommend: String(localized: "Don't recommend")
        }
    }
}

nonisolated enum HeardFrom: String, Codable, CaseIterable, Identifiable, Sendable {
    case tiktok, instagram, youtube, facebook, x, friends, appStore, google, tv, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .youtube: "YouTube"
        case .facebook: "Facebook"
        case .x: "X"
        case .friends: String(localized: "Friends or family")
        case .appStore: "App Store"
        case .google: "Google"
        case .tv: String(localized: "TV")
        case .other: String(localized: "Other")
        }
    }
}

/// Common dislikes with the ingredient terms they exclude.
nonisolated enum DislikeCatalog {
    static let common: [String] = ["Mushrooms", "Olives", "Onions", "Cilantro", "Seafood", "Tomatoes", "Avocado", "Spicy food", "Eggs", "Tofu"]

    static func terms(for dislike: String) -> [String] {
        switch dislike.lowercased() {
        case "mushrooms": ["mushroom"]
        case "olives": ["olive"]
        case "onions": ["onion"]
        case "cilantro": ["cilantro"]
        case "seafood": ["salmon", "shrimp", "fish", "tuna", "cod"]
        case "tomatoes": ["tomato", "salsa"]
        case "avocado": ["avocado"]
        case "eggs": ["egg"]
        case "tofu": ["tofu"]
        case "spicy food": ["__spicy__"]
        default: [dislike.lowercased()]
        }
    }
}
