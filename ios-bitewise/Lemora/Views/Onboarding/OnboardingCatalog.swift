import SwiftUI

/// Question options, copy and reactions of the v2 onboarding (verbatim from the design).
enum OBCatalog {
    struct Option: Identifiable { let id: String; let icon: String; let label: String }
    struct Goal: Identifiable { let id: String; let icon: String; let iconBg: UInt32; let label: String; let sub: String }
    struct Diet: Identifiable { let id: String; let icon: String; let label: String; let sub: String }
    struct Conflict { let a: String; let b: String; let message: String }
    struct Strategy: Identifiable { let id: String; let icon: String; let bg: UInt32; let label: String; let sub: String }

    static let hear: [Option] = [
        .init(id: "tiktok", icon: "🎵", label: "TikTok"), .init(id: "instagram", icon: "📸", label: "Instagram"),
        .init(id: "youtube", icon: "▶️", label: "YouTube"), .init(id: "facebook", icon: "👍", label: "Facebook"),
        .init(id: "google", icon: "🔎", label: "Google"), .init(id: "app_store", icon: "⭐", label: "App Store"),
        .init(id: "friends_family", icon: "💬", label: "Friends or Family"), .init(id: "other", icon: "✦", label: "Other"),
    ]

    static let goals: [Goal] = [
        .init(id: "save_money", icon: "💰", iconBg: 0xFCF1BF, label: "Save Money on Groceries", sub: "Best deals near you, every week"),
        .init(id: "eat_healthier", icon: "🥦", iconBg: 0xEAF5E4, label: "Eat Healthier", sub: "More whole foods, less guesswork"),
        .init(id: "lose_weight", icon: "🍋", iconBg: 0xEAF5E4, label: "Lose Weight", sub: "Lighter meals that still fill you up"),
        .init(id: "build_muscle", icon: "💪", iconBg: 0xFDEBDD, label: "Build Muscle", sub: "High protein at the lowest cost"),
        .init(id: "gain_weight", icon: "🍚", iconBg: 0xFDEBDD, label: "Gain Weight", sub: "Calorie-dense, budget-friendly"),
        .init(id: "maintain_weight", icon: "⚖️", iconBg: 0xF1EADB, label: "Maintain Weight", sub: "Balanced portions, steady routine"),
        .init(id: "discover_meals", icon: "✨", iconBg: 0xFCF1BF, label: "Discover Better Meals", sub: "New flavours you’ll actually cook"),
        .init(id: "meal_prep", icon: "🥡", iconBg: 0xEAF5E4, label: "Meal Prep", sub: "Cook once, eat well all week"),
    ]

    static let reminder: [String: String] = [
        "save_money": "Every week, the best prices near you come first.",
        "eat_healthier": "Spend smarter while finding meals that fit the way you want to eat.",
        "lose_weight": "Save on groceries while discovering meals aligned with your goal.",
        "build_muscle": "Save money while staying focused on building muscle.",
        "gain_weight": "Save on groceries while hitting your calorie goals.",
        "maintain_weight": "Save money while keeping your meals balanced and steady.",
        "discover_meals": "Spend less while finding meals you’ll actually want to cook.",
        "meal_prep": "Prep more for less, with batches built around this week’s deals.",
    ]

    static let goalReaction: [String: String] = [
        "save_money": "My favourite. Let’s find the deals.", "build_muscle": "Protein on a budget is my specialty.",
        "lose_weight": "Lighter meals, same flavour.", "eat_healthier": "More good stuff, less guesswork.",
        "gain_weight": "Hearty meals coming up.", "maintain_weight": "Steady and balanced. Nice.",
        "discover_meals": "Ooh, I love new recipes.", "meal_prep": "Batch cooking saves the most.",
    ]

    static let diets: [Diet] = [
        .init(id: "plant_based", icon: "🌱", label: "Plant-Based", sub: "Mostly plants"),
        .init(id: "whole_food", icon: "🥕", label: "Whole-Food Focused", sub: "Minimally processed"),
        .init(id: "mediterranean", icon: "🫒", label: "Mediterranean", sub: "Olive oil, fish, veg"),
        .init(id: "flexitarian", icon: "🥗", label: "Flexitarian", sub: "Mostly veg, some meat"),
        .init(id: "pescatarian", icon: "🐟", label: "Pescatarian", sub: "Fish, no meat"),
        .init(id: "vegetarian", icon: "🥚", label: "Vegetarian", sub: "No meat or fish"),
        .init(id: "vegan", icon: "🌿", label: "Vegan", sub: "No animal products"),
        .init(id: "low_carb", icon: "🥩", label: "Low Carb", sub: "Fewer carbs"),
        .init(id: "keto", icon: "🥑", label: "Keto", sub: "Very low carb"),
        .init(id: "high_protein", icon: "💪", label: "High Protein", sub: "Protein first"),
        .init(id: "gluten_free", icon: "🌾", label: "Gluten-Free", sub: "No gluten"),
        .init(id: "lactose_free", icon: "🥛", label: "Lactose-Free", sub: "No lactose"),
        .init(id: "halal", icon: "🥙", label: "Halal", sub: "Halal only"),
        .init(id: "kosher", icon: "🥯", label: "Kosher", sub: "Kosher only"),
    ]

    static let meals: [Diet] = [
        .init(id: "breakfast", icon: "🥞", label: "Breakfast", sub: "Start the day right"),
        .init(id: "lunch", icon: "🥪", label: "Lunch", sub: "Easy midday meals"),
        .init(id: "dinner", icon: "🍝", label: "Dinner", sub: "Weeknight & family"),
        .init(id: "snack", icon: "🍿", label: "Snacks", sub: "Quick bites"),
        .init(id: "dessert", icon: "🍰", label: "Desserts", sub: "Something sweet"),
    ]

    static let dietLabel: [String: String] = {
        var d = Dictionary(uniqueKeysWithValues: diets.map { ($0.id, $0.label) })
        d["none"] = "No Specific Diet"
        return d
    }()

    static let conflicts: [Conflict] = [
        .init(a: "vegan", b: "vegetarian", message: "Vegan already covers vegetarian"),
        .init(a: "vegan", b: "pescatarian", message: "Vegan and pescatarian can’t both apply"),
        .init(a: "vegan", b: "flexitarian", message: "Vegan and flexitarian can’t both apply"),
        .init(a: "vegetarian", b: "pescatarian", message: "Vegetarian excludes fish, so pescatarian was removed"),
        .init(a: "vegetarian", b: "flexitarian", message: "Vegetarian and flexitarian can’t both apply"),
        .init(a: "pescatarian", b: "flexitarian", message: "Pescatarian and flexitarian can’t both apply"),
        .init(a: "keto", b: "low_carb", message: "Keto is already low carb"),
    ]

    static let quickAllergy = ["peanut", "tree_nut", "milk", "egg", "wheat", "soy", "fish", "shellfish", "sesame", "mustard"]

    static let allergyIcon: [String: String] = [
        "peanut": "🥜", "tree_nut": "🌰", "milk": "🥛", "egg": "🥚", "wheat": "🌾", "soy": "🫘", "fish": "🐟", "shellfish": "🦐",
        "sesame": "🥯", "mustard": "🌭", "gluten": "🍞", "shrimp": "🦐", "crab": "🦀", "lobster": "🦞", "almond": "🌰", "cashew": "🌰",
        "walnut": "🌰", "hazelnut": "🌰", "celery": "🥬", "corn": "🌽", "kiwi": "🥝", "coconut": "🥥", "peach": "🍑", "strawberry": "🍓",
        "banana": "🍌", "avocado": "🥑", "garlic": "🧄", "squid": "🦑", "oyster": "🦪", "pea": "🫛", "pea_protein": "🫛",
        "chickpea": "🫘", "lentil": "🫘",
    ]

    static let quickDislike: [(id: String, icon: String)] = [
        ("mushroom", "🍄"), ("olive", "🫒"), ("onion", "🧅"), ("tomato", "🍅"), ("cilantro", "🌿"),
        ("seafood", "🦐"), ("avocado", "🥑"), ("eggplant", "🍆"), ("pickle", "🥒"), ("spicy", "🌶️"),
    ]

    static let strategies: [Strategy] = [
        .init(id: "one", icon: "🏪", bg: 0xFCF1BF, label: "ONE STORE", sub: "Keep it simple. Prefer one grocery store."),
        .init(id: "balanced", icon: "⚖️", bg: 0xEAF5E4, label: "BALANCED", sub: "Use another store when the savings are worth it."),
        .init(id: "max", icon: "🏷️", bg: 0xFDEBDD, label: "MAX SAVINGS", sub: "Find the best deals across multiple stores."),
    ]

    static let strategyReaction: [String: String] = ["one": "Simple it is.", "balanced": "Smart balance.", "max": "Deal hunter mode on."]

    static let cuisines: [(id: String, label: String, icon: String)] = [
        ("italian", "Italian", "🍝"), ("mexican", "Mexican", "🌮"), ("japanese", "Japanese", "🍣"), ("korean", "Korean", "🥢"),
        ("indian", "Indian", "🍛"), ("greek", "Greek", "🥙"), ("lebanese", "Lebanese", "🧆"), ("french", "French", "🥐"),
        ("thai", "Thai", "🍜"), ("vietnamese", "Vietnamese", "🍲"), ("caribbean", "Caribbean", "🌴"), ("comfort", "Comfort food", "🍔"),
    ]

    static let tints: [UInt32] = [0xE5483A, 0x10362B, 0xF0913A, 0x2F9E4F, 0x2A6FDB, 0xC8412F, 0x7A5AD8, 0x1B7F8C, 0xB8860B]
    static let moreTints: [UInt32] = [0x7A8A5E, 0xC67139, 0x1B7F8C, 0x8A5A9E, 0xB8860B, 0x2F9E4F]

    static func initials(_ name: String) -> String {
        let letters = name.filter { $0.isASCII && ($0.isLetter || $0 == "&" || $0 == " ") }
        let words = letters.split(whereSeparator: { $0 == " " || $0 == "&" })
        let s = words.compactMap(\.first).map(String.init).joined().prefix(3).uppercased()
        return s.isEmpty ? String(name.prefix(2)) : s
    }

    /// Logo image for the "How did you hear about us?" tiles.
    static func hearLogo(_ id: String) -> String? {
        switch id {
        case "tiktok": "logo_tiktok"
        case "instagram": "logo_instagram"
        case "youtube": "logo_youtube"
        case "facebook": "logo_facebook"
        case "google": "logo_google_box"
        case "app_store": "logo_appstore"
        default: nil
        }
    }
}
