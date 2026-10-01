import Foundation

nonisolated enum TriState: String, Codable, Sendable {
    case yes, no, uncertain
}

/// UserGoal: the user's main objective. Reused by ranking, the savings reminder and the plan.
nonisolated enum Goal: String, Codable, CaseIterable, Identifiable, Sendable {
    case saveMoney, eatHealthier, loseWeight, buildMuscle, gainWeight, maintain, discover, mealPrep, other

    static let onboardingCases: [Goal] = [.saveMoney, .eatHealthier, .loseWeight, .buildMuscle, .gainWeight, .maintain, .discover, .mealPrep]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveMoney: String(localized: "Save Money on Groceries")
        case .eatHealthier: String(localized: "Eat Healthier")
        case .loseWeight: String(localized: "Lose Weight")
        case .buildMuscle: String(localized: "Build Muscle")
        case .gainWeight: String(localized: "Gain Weight")
        case .maintain: String(localized: "Maintain Weight")
        case .discover: String(localized: "Discover Better Meals")
        case .mealPrep: String(localized: "Meal Prep")
        case .other: String(localized: "Something Else")
        }
    }

    var subtitle: String {
        switch self {
        case .saveMoney: String(localized: "Spend less every week")
        case .eatHealthier: String(localized: "More balanced, whole meals")
        case .loseWeight: String(localized: "Lighter meals that still fill you up")
        case .buildMuscle: String(localized: "Protein-packed meals")
        case .gainWeight: String(localized: "Hearty, satisfying meals")
        case .maintain: String(localized: "Keep things steady")
        case .discover: String(localized: "New favorites every week")
        case .mealPrep: String(localized: "Cook once, eat all week")
        case .other: String(localized: "A bit of everything")
        }
    }

    var symbol: String {
        switch self {
        case .saveMoney: "dollarsign.circle.fill"
        case .eatHealthier: "leaf.fill"
        case .loseWeight: "figure.walk"
        case .buildMuscle: "dumbbell.fill"
        case .gainWeight: "arrow.up.right.circle.fill"
        case .maintain: "equal.circle.fill"
        case .discover: "sparkles"
        case .mealPrep: "takeoutbag.and.cup.and.straw.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var needsBodyMetrics: Bool {
        self == .loseWeight || self == .buildMuscle || self == .gainWeight
    }

    /// Zest's reaction when this goal is picked.
    var reaction: String {
        switch self {
        case .saveMoney: String(localized: "Love it. Every plan will put savings first.")
        case .eatHealthier: String(localized: "Fresh, balanced meals it is.")
        case .loseWeight: String(localized: "I'll find lighter meals that still fill you up.")
        case .buildMuscle: String(localized: "Protein-packed meals coming right up.")
        case .gainWeight: String(localized: "Hearty, satisfying meals. I'm on it.")
        case .maintain: String(localized: "Balanced meals to keep you steady.")
        case .discover: String(localized: "Ooh, I love trying new things too!")
        case .mealPrep: String(localized: "Batch-friendly meals that save you time.")
        case .other: String(localized: "Got it!")
        }
    }

    /// Shown under the savings estimate: Lemora always helps save, plus the personal goal.
    var savingsReminder: String {
        switch self {
        case .saveMoney: String(localized: "Saving money is your main goal, so every plan puts the best deals first.")
        case .eatHealthier: String(localized: "Spend smarter while finding meals that fit the way you want to eat.")
        case .loseWeight: String(localized: "Save on groceries while discovering meals aligned with your goal.")
        case .buildMuscle: String(localized: "Save money while staying focused on building muscle.")
        case .gainWeight: String(localized: "Save on groceries while eating hearty meals that support your goal.")
        case .maintain: String(localized: "Save on groceries while keeping your meals balanced and steady.")
        case .discover: String(localized: "Save on groceries while discovering meals you'll actually love.")
        case .mealPrep: String(localized: "Save money and time with batch-friendly meals built around deals.")
        case .other: String(localized: "Save on groceries with meals picked just for you.")
        }
    }
}

/// UserDietPreferences are a set of these. Strict diets are hard filters; soft ones shape ranking.
nonisolated enum DietPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case everything, plantBased, wholeFood, mediterranean, flexitarian, pescatarian, vegetarian, vegan
    case lowCarb, keto, highProtein, glutenFree, lactoseFree, dairyFree, halal, kosher

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everything: String(localized: "No Specific Diet")
        case .plantBased: String(localized: "Plant-Based")
        case .wholeFood: String(localized: "Whole-Food Focused")
        case .mediterranean: String(localized: "Mediterranean")
        case .flexitarian: String(localized: "Flexitarian")
        case .pescatarian: String(localized: "Pescatarian")
        case .vegetarian: String(localized: "Vegetarian")
        case .vegan: String(localized: "Vegan")
        case .lowCarb: String(localized: "Low Carb")
        case .keto: String(localized: "Keto")
        case .highProtein: String(localized: "High Protein")
        case .glutenFree: String(localized: "Gluten-Free")
        case .lactoseFree: String(localized: "Lactose-Free")
        case .dairyFree: String(localized: "Dairy-Free")
        case .halal: String(localized: "Halal")
        case .kosher: String(localized: "Kosher")
        }
    }

    var subtitle: String {
        switch self {
        case .everything: String(localized: "Everything's on the menu")
        case .plantBased: String(localized: "Only foods from plants")
        case .wholeFood: String(localized: "Minimally processed")
        case .mediterranean: String(localized: "Veggies, fish, olive oil")
        case .flexitarian: String(localized: "Mostly plants, some meat")
        case .pescatarian: String(localized: "Fish, no meat")
        case .vegetarian: String(localized: "No meat or fish")
        case .vegan: String(localized: "No animal products")
        case .lowCarb: String(localized: "Fewer carbs")
        case .keto: String(localized: "Very low carb")
        case .highProtein: String(localized: "Protein first")
        case .glutenFree: String(localized: "No gluten")
        case .lactoseFree: String(localized: "No lactose")
        case .dairyFree: String(localized: "No dairy at all")
        case .halal: String(localized: "No pork")
        case .kosher: String(localized: "No pork or shellfish")
        }
    }

    var symbol: String {
        switch self {
        case .everything: "fork.knife"
        case .plantBased: "leaf.fill"
        case .wholeFood: "carrot.fill"
        case .mediterranean: "sun.max.fill"
        case .flexitarian: "arrow.triangle.2.circlepath"
        case .pescatarian: "fish.fill"
        case .vegetarian: "leaf"
        case .vegan: "leaf.circle.fill"
        case .lowCarb: "chart.line.downtrend.xyaxis"
        case .keto: "flame.fill"
        case .highProtein: "dumbbell.fill"
        case .glutenFree: "circle.slash"
        case .lactoseFree: "drop.fill"
        case .dairyFree: "cup.and.saucer.fill"
        case .halal: "moon.stars.fill"
        case .kosher: "checkmark.seal.fill"
        }
    }

    /// Strict diets are hard filters. Soft ones only influence ranking.
    var isStrict: Bool {
        switch self {
        case .everything, .wholeFood, .mediterranean, .flexitarian, .lowCarb, .highProtein: false
        default: true
        }
    }
}

/// Real compatibility rules so a diet profile can never contradict itself.
nonisolated enum DietRules {
    struct Resolution: Sendable {
        let diets: Set<DietPreference>
        /// Short explanation when Lemora resolved a conflict for the user.
        let note: String?
    }

    /// Eating patterns about animal products. Only one can apply at a time.
    static let patterns: Set<DietPreference> = [.vegan, .plantBased, .vegetarian, .pescatarian, .flexitarian]

    /// True when every meal that satisfies `a` automatically satisfies `b`.
    static func implies(_ a: DietPreference, _ b: DietPreference) -> Bool {
        switch (a, b) {
        case (.vegan, .lactoseFree), (.vegan, .dairyFree), (.plantBased, .lactoseFree), (.plantBased, .dairyFree),
             (.dairyFree, .lactoseFree), (.keto, .lowCarb):
            true
        default:
            false
        }
    }

    static func conflicts(_ a: DietPreference, _ b: DietPreference) -> Bool {
        a != b && patterns.contains(a) && patterns.contains(b)
    }

    static func toggle(_ diet: DietPreference, in current: Set<DietPreference>) -> Resolution {
        if diet == .everything {
            return Resolution(diets: current == [.everything] ? [] : [.everything], note: nil)
        }
        var set = current
        set.remove(.everything)
        if set.contains(diet) {
            set.remove(diet)
            return Resolution(diets: set, note: nil)
        }
        if let parent = set.first(where: { implies($0, diet) }) {
            return Resolution(diets: set, note: String(localized: "\(parent.title) meals are already \(diet.title.lowercased()), so you're covered."))
        }
        let redundant = set.filter { implies(diet, $0) }
        let replaced = set.filter { conflicts(diet, $0) }
        set.subtract(redundant)
        set.subtract(replaced)
        set.insert(diet)
        var note: String? = nil
        if let old = replaced.first {
            note = String(localized: "\(diet.title) replaces \(old.title). You can follow one eating style at a time.")
        } else if let old = redundant.first {
            note = String(localized: "\(diet.title) already covers \(old.title.lowercased()).")
        }
        return Resolution(diets: set, note: note)
    }

    /// A valid profile has no conflicting patterns, no redundant pairs and an exclusive "No Specific Diet".
    static func isValid(_ diets: Set<DietPreference>) -> Bool {
        if diets.contains(.everything) && diets.count > 1 { return false }
        if diets.filter({ patterns.contains($0) }).count > 1 { return false }
        for a in diets { for b in diets where implies(a, b) { return false } }
        return true
    }
}

/// Core allergen flags carried by recipe ingredients (`contains` / `mayContain`).
/// User allergies reference the larger allergen database, which maps onto these.
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

    /// Allergen-database id for legacy values.
    var databaseId: String {
        switch self {
        case .peanuts: "peanut"
        case .treeNuts: "tree_nuts"
        default: rawValue
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

nonisolated enum MealType: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakfast, lunch, dinner, snack, dessert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: String(localized: "Breakfast")
        case .lunch: String(localized: "Lunch")
        case .dinner: String(localized: "Dinner")
        case .snack: String(localized: "Snacks")
        case .dessert: String(localized: "Desserts")
        }
    }

    var emoji: String {
        switch self {
        case .breakfast: "🥞"
        case .lunch: "🥪"
        case .dinner: "🍝"
        case .snack: "🍿"
        case .dessert: "🍰"
        }
    }
}

/// UserShoppingStrategy. Raw values are stable storage keys.
nonisolated enum ShoppingStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
    case convenience, balanced, maximumSavings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .convenience: String(localized: "One Store")
        case .balanced: String(localized: "Balanced")
        case .maximumSavings: String(localized: "Max Savings")
        }
    }

    var subtitle: String {
        switch self {
        case .convenience: String(localized: "Keep it simple. Prefer one grocery store.")
        case .balanced: String(localized: "Use another store when the savings are worth it.")
        case .maximumSavings: String(localized: "Find the best deals across multiple stores.")
        }
    }

    var symbol: String {
        switch self {
        case .convenience: "bag.fill"
        case .balanced: "scalemass.fill"
        case .maximumSavings: "chart.line.uptrend.xyaxis"
        }
    }

    var reaction: String {
        switch self {
        case .convenience: String(localized: "Simple and quick. One store it is.")
        case .balanced: String(localized: "Smart. I'll only suggest a second store when it's worth it.")
        case .maximumSavings: String(localized: "Deal hunter! I'll dig through every store you picked.")
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

/// ReferralSource: "How did you hear about us?" Stored on the profile and sent to analytics.
nonisolated enum ReferralSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case tiktok, instagram, youtube, facebook, google, appStore, friends, other, x, tv

    static let onboardingCases: [ReferralSource] = [.tiktok, .instagram, .youtube, .facebook, .google, .appStore, .friends, .other]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .youtube: "YouTube"
        case .facebook: "Facebook"
        case .google: "Google"
        case .appStore: "App Store"
        case .friends: String(localized: "Friends or Family")
        case .other: String(localized: "Other")
        case .x: "X"
        case .tv: String(localized: "TV")
        }
    }

    var symbol: String {
        switch self {
        case .tiktok: "music.note"
        case .instagram: "camera.fill"
        case .youtube: "play.rectangle.fill"
        case .facebook: "f.circle.fill"
        case .google: "magnifyingglass"
        case .appStore: "a.circle.fill"
        case .friends: "person.2.fill"
        case .other: "ellipsis"
        case .x: "xmark"
        case .tv: "tv.fill"
        }
    }
}

/// NotificationPreference: what happened on the Lemora primer and the system prompt.
nonisolated enum NotificationPreference: String, Codable, Sendable {
    case notAsked, declinedPrimer, granted, denied
}
