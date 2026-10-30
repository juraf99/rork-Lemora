import Foundation

/// Strict ingredient matching between recipes and weekly deals.
/// A deal prices a recipe line only when it is the same food (cherry tomatoes never price "tomatoes").
/// Near-identical alternatives are never applied silently: Zesty suggests them as swaps, only when they
/// are clearly cheaper and cannot change the dish.
nonisolated enum IngredientMatch {
    struct SwapRule: Sendable {
        /// Deal food type that can stand in for the recipe ingredient.
        let type: String
        /// Short, practical explanation shown by Zesty.
        let note: String
        /// Words in the recipe title or ingredient line that rule the swap out (stuffed peppers, Caesar salad, sushi…).
        let blockedWords: [String]
    }

    /// Recipe ingredient id -> deal food types that are the same food.
    static let exact: [String: [String]] = [
        "almond": ["almonds"],
        "apple": ["apple"],
        "arugula": ["arugula"],
        "asparagus": ["asparagus"],
        "avocado": ["avocado"],
        "banana": ["banana"],
        "beef_minced": ["beef_ground_lean", "beef_ground", "ground_beef"],
        "beet": ["beet", "beets"],
        "bell_pepper": ["pepper", "bell_pepper"],
        "black_beans": ["beans_black", "black_beans"],
        "blueberry": ["blueberries"],
        "bok_choy": ["bok_choy"],
        "broccoli": ["broccoli"],
        "brussels_sprout": ["brussels", "brussels_sprouts"],
        "butter": ["butter"],
        "cabbage": ["cabbage"],
        "cantaloupe": ["cantaloupe"],
        "carrot": ["carrot"],
        "carrot_purple": ["carrot_purple"],
        "cauliflower": ["cauliflower"],
        "celery": ["celery"],
        "cheddar": ["cheddar"],
        "cherry_tomato": ["tomato_cherry", "cherry_tomato"],
        "cherry_tomatoes": ["tomato_cherry"],
        "chicken": ["chicken_breast"],
        "chicken_breast": ["chicken_breast"],
        "chicken_drumstick": ["chicken_drumstick"],
        "chicken_leg": ["chicken_leg"],
        "chicken_thigh": ["chicken_thigh"],
        "chickpeas": ["chickpeas"],
        "clementine": ["clementine"],
        "cod": ["cod"],
        "cooked_beet": ["beets"],
        "corn": ["corn"],
        "cottage": ["cottage"],
        "crab": ["crab"],
        "cucumber": ["cucumber"],
        "egg": ["eggs", "egg"],
        "eggplant": ["eggplant"],
        "eggs": ["eggs", "egg"],
        "feta": ["feta"],
        "firm_tofu": ["tofu"],
        "garlic": ["garlic"],
        "ginger": ["ginger"],
        "grapes": ["grapes"],
        "greek_yogurt": ["yogurt_greek", "greek_yogurt", "greek_yogurt_or_skyr"],
        "green_bean": ["green_beans"],
        "green_pepper": ["green_peppers"],
        "greens": ["lettuce"],
        "ground_beef": ["beef_ground_lean", "beef_ground", "ground_beef"],
        "ground_pork": ["pork_ground", "ground_pork"],
        "ground_turkey": ["turkey_ground"],
        "haddock": ["haddock"],
        "kale": ["kale"],
        "kiwi": ["kiwi"],
        "lamb": ["lamb"],
        "leek": ["leek"],
        "lemon": ["lemon"],
        "lemon_juice": ["lemon"],
        "lemon_zest": ["lemon"],
        "lentils": ["lentils"],
        "lettuce": ["lettuce", "lettuce_romaine"],
        "lime": ["lime"],
        "lime_juice": ["lime"],
        "lime_zest": ["lime"],
        "mango": ["mango"],
        "milk": ["milk"],
        "mozzarella": ["mozzarella"],
        "mushroom": ["mushroom"],
        "mussel": ["mussels"],
        "napa": ["napa_cabbage"],
        "oats": ["oats"],
        "olive_oil": ["olive_oil"],
        "onion": ["onion"],
        "orange": ["orange"],
        "parmesan": ["parmesan"],
        "peach": ["peach"],
        "pear": ["pear"],
        "pepper": ["pepper", "bell_pepper"],
        "pineapple": ["pineapple"],
        "pork": ["pork_tenderloin"],
        "pork_tenderloin": ["pork_tenderloin"],
        "portobello": ["mushroom_portobello"],
        "potato": ["potato"],
        "quinoa": ["quinoa"],
        "radish": ["radish"],
        "raspberry": ["raspberries"],
        "red_bell_pepper": ["pepper", "bell_pepper"],
        "red_cabbage": ["red_cabbage"],
        "red_onion": ["onion_red"],
        "red_pepper": ["pepper", "bell_pepper"],
        "romaine": ["lettuce_romaine"],
        "salmon": ["salmon_fillet", "salmon"],
        "sardine": ["sardines", "sardine"],
        "scallion": ["onion_green", "green_onion"],
        "shiitake": ["shiitake"],
        "shrimp": ["shrimp"],
        "smoked_salmon": ["salmon_smoked"],
        "snow_pea": ["snap_peas"],
        "spinach": ["spinach"],
        "squash": ["squash"],
        "strawberry": ["strawberries"],
        "sweet_potato": ["sweet_potato"],
        "tempeh": ["tempeh"],
        "tilapia": ["tilapia"],
        "tofu": ["tofu"],
        "tomato": ["tomato", "tomato_vine", "tomato_roma", "tomato_heirloom"],
        "trout": ["trout"],
        "tuna": ["tuna_canned"],
        "veal": ["veal"],
        "yellow_pepper": ["pepper", "bell_pepper"],
        "yogurt": ["yogurt"],
        "zucchini": ["zucchini"]
    ]

    /// Recipe ingredient id -> recipe-safe, near-identical alternatives. Deliberately short.
    static let swaps: [String: [SwapRule]] = [
        "bell_pepper": [
            SwapRule(type: "pepper_mini", note: "Mini sweet peppers taste the same. Use about 4 for 1 pepper.", blockedWords: ["stuffed", "farci", "roasted whole"])
        ],
        "chicken_leg": [
            SwapRule(type: "chicken_drumstick", note: "Drumsticks are the same cut, just smaller. Same cooking time.", blockedWords: []),
            SwapRule(type: "chicken_thigh", note: "Thighs are the other half of the leg. Same flavour, slightly faster to cook.", blockedWords: [])
        ],
        "cod": [
            SwapRule(type: "haddock", note: "Haddock is a mild white fish that cooks exactly like cod.", blockedWords: ["salt cod", "bacalao", "morue salée"])
        ],
        "cucumber": [
            SwapRule(type: "cucumber_mini", note: "Mini cucumbers are the same vegetable, just smaller. Use about 5 for 1 English cucumber.", blockedWords: ["spiral", "boat", "stuffed"])
        ],
        "ground_turkey": [
            SwapRule(type: "chicken_ground", note: "Ground chicken is just as lean and cooks the same way.", blockedWords: [])
        ],
        "haddock": [
            SwapRule(type: "cod", note: "Cod is a mild white fish that cooks exactly like haddock.", blockedWords: ["smoked", "finnan"])
        ],
        "potato": [
            SwapRule(type: "potato_baby", note: "Baby potatoes cook the same way. Halve them so they cook evenly.", blockedWords: ["mash", "purée", "puree", "fries", "frites", "baked potato", "jacket", "hash", "gratin", "latke", "wedge", "rösti", "rosti", "gnocchi", "stuffed", "scallop"])
        ],
        "red_bell_pepper": [
            SwapRule(type: "pepper_mini", note: "Mini sweet peppers taste the same. Use about 4 for 1 pepper.", blockedWords: ["stuffed", "farci", "roasted whole"])
        ],
        "red_pepper": [
            SwapRule(type: "pepper_mini", note: "Mini sweet peppers taste the same. Use about 4 for 1 pepper.", blockedWords: ["stuffed", "farci", "roasted whole"])
        ],
        "romaine": [
            SwapRule(type: "lettuce", note: "Any crisp green lettuce works the same here.", blockedWords: ["caesar", "césar", "grill", "boat", "wrap"])
        ],
        "salmon": [
            SwapRule(type: "trout", note: "Trout is very close to salmon and cooks exactly the same way.", blockedWords: ["sushi", "sashimi", "poke", "poké", "tartare", "ceviche", "gravlax", "smoked", "cured", "raw"])
        ],
        "tomato": [
            SwapRule(type: "tomato_cherry", note: "Cherry tomatoes give the same flavour. Halve them before using.", blockedWords: ["stuffed", "farci", "slice", "tranche", "burger", "sandwich", "blt", "caprese", "grilled tomato", "roasted tomato halves"])
        ],
        "trout": [
            SwapRule(type: "salmon_fillet", note: "Salmon is very close to trout and cooks exactly the same way.", blockedWords: ["sushi", "sashimi", "poke", "poké", "tartare", "ceviche", "gravlax", "smoked", "cured", "raw"])
        ],
        "yellow_pepper": [
            SwapRule(type: "pepper_mini", note: "Mini sweet peppers taste the same. Use about 4 for 1 pepper.", blockedWords: ["stuffed", "farci", "roasted whole"])
        ],
        "yogurt": [
            SwapRule(type: "yogurt_greek", note: "Plain Greek yogurt works the same, it is just thicker.", blockedWords: ["baking", "cake", "muffin", "bread", "marinade"])
        ]
    ]

    /// Typical weight of one piece, used to compare a recipe's "2 tomatoes" with a per-lb or per-pack price.
    static let gramsPerUnit: [String: Double] = [
        "cucumber": 340, "cucumber_mini": 60, "bell_pepper": 160, "red_bell_pepper": 160, "red_pepper": 160,
        "yellow_pepper": 160, "green_pepper": 160, "pepper": 160, "pepper_mini": 35, "tomato": 120, "tomato_cherry": 15,
        "potato": 215, "potato_baby": 40, "sweet_potato": 250, "onion": 150, "red_onion": 150, "carrot": 70,
        "zucchini": 200, "eggplant": 450, "apple": 180, "pear": 180, "orange": 170, "banana": 120, "avocado": 170,
        "lemon": 100, "lime": 65, "mango": 300, "chicken_breast": 250, "chicken_leg": 300, "chicken_drumstick": 110,
        "chicken_thigh": 130, "salmon": 150, "salmon_fillet": 150, "trout": 150, "cod": 150, "haddock": 150,
        "broccoli": 400, "cauliflower": 700, "leek": 250, "celery": 450, "romaine": 600, "lettuce": 450,
    ]

    /// Aliases that are too broad to price a specific ingredient ("beef" for flank steak).
    private static let generic: Set<String> = ["beef", "pork", "chicken", "fish", "seafood", "meat", "pasta", "cheese",
                                               "yogurt", "peppers", "rice", "broth", "squash", "potato", "berries"]

    /// Readable names for the precise food types used by deals and grocery items.
    static let typeNames: [String: String] = [
        "tomato_cherry": "Cherry tomatoes", "tomato_vine": "Tomatoes on the vine", "tomato_roma": "Roma tomatoes",
        "tomato_heirloom": "Heirloom tomatoes", "cucumber_mini": "Mini cucumbers", "pepper": "Bell peppers",
        "pepper_mini": "Mini sweet peppers", "potato_baby": "Baby potatoes", "onion_red": "Red onions",
        "onion_green": "Green onions", "lettuce_romaine": "Romaine lettuce", "mushroom_portobello": "Portobello mushrooms",
        "chicken_drumstick": "Chicken drumsticks", "chicken_thigh": "Chicken thighs", "chicken_ground": "Ground chicken",
        "beef_ground": "Ground beef", "beef_ground_lean": "Lean ground beef", "beef_steak": "Beef steak",
        "pork_ground": "Ground pork", "pork_ribs": "Pork ribs", "turkey_ground": "Ground turkey",
        "salmon_fillet": "Salmon fillets", "salmon_smoked": "Smoked salmon", "tuna_steak": "Tuna steaks",
        "tuna_canned": "Canned tuna", "yogurt_greek": "Greek yogurt", "melon_honeydew": "Honeydew melon",
        "green_beans": "Green beans", "brussels": "Brussels sprouts", "snap_peas": "Snap peas",
    ]

    /// Deal food types that count as this exact recipe ingredient.
    static func dealKeys(for ingredientId: String) -> [String] {
        var out = [ingredientId]
        let aliases = exact[ingredientId]
            ?? CatalogIngredientInfo.dealIds(for: ingredientId).filter { !generic.contains($0) }
        for alias in aliases where !out.contains(alias) { out.append(alias) }
        return out
    }

    static func matches(_ ingredientId: String, dealKey: String) -> Bool {
        dealKeys(for: ingredientId).contains(dealKey)
    }

    /// Grams the recipe line needs, when it can be known.
    static func grams(_ quantity: Double, _ unit: IngredientUnit, ingredientId: String) -> Double? {
        switch unit {
        case .g: return quantity
        case .unit: return gramsPerUnit[ingredientId].map { $0 * quantity }
        default: return nil
        }
    }
}

/// "Zesty found a cheaper swap": a near-identical product on sale at one of the user's stores.
nonisolated struct SmartSwap: Identifiable, Sendable {
    var id: String { ingredientId + "|" + deal.id }
    let ingredientId: String
    let deal: Deal
    let note: String
    let baseCost: Double
    let swapCost: Double
    var saving: Double { baseCost - swapCost }
}

nonisolated enum SmartSwaps {
    /// Minimum saving before Zesty speaks up: at least 15% and $0.30 on that line.
    static let minFraction = 0.15
    static let minAmount = 0.30

    static func find(recipe: Recipe, price: RecipePrice, deals: [Deal], dislikedIds: Set<String>, now: Date = .now) -> [SmartSwap] {
        let context = (recipe.title + " " + recipe.summary).lowercased()
        let byType = Dictionary(grouping: deals.filter { $0.validUntil >= now && !$0.isSampleData }, by: \.ingredientId)
        var found: [SmartSwap] = []
        for line in price.lines {
            guard let rules = IngredientMatch.swaps[line.ingredientId], let base = line.cost, base > 0 else { continue }
            let raw = recipe.ingredients.first { $0.ingredientId == line.ingredientId }?.rawText.lowercased() ?? ""
            var best: SmartSwap?
            for rule in rules {
                if dislikedIds.contains(rule.type) { continue }
                if rule.blockedWords.contains(where: { context.contains($0) || raw.contains($0) }) { continue }
                // The recipe must not already use the alternative.
                if recipe.ingredients.contains(where: { IngredientMatch.matches($0.ingredientId, dealKey: rule.type) }) { continue }
                for deal in byType[rule.type] ?? [] {
                    guard let cost = swapCost(deal, line: line, swapType: rule.type) else { continue }
                    let saving = base - cost
                    guard saving >= minAmount, saving / base >= minFraction else { continue }
                    if best == nil || cost < best!.swapCost {
                        best = SmartSwap(ingredientId: line.ingredientId, deal: deal, note: rule.note, baseCost: base, swapCost: cost)
                    }
                }
            }
            if let best { found.append(best) }
        }
        return Array(found.sorted { $0.saving > $1.saving }.prefix(2))
    }

    /// What the swap really costs at the till for the quantity the recipe needs. Unknown sizes are skipped.
    static func swapCost(_ deal: Deal, line: PriceLine, swapType: String) -> Double? {
        // A head of lettuce replaces a head of lettuce.
        if line.unit == .unit, swapType == "lettuce", deal.isPiecePriced { return deal.effectivePrice * line.quantity.rounded(.up) }
        guard let grams = IngredientMatch.grams(line.quantity, line.unit, ingredientId: line.ingredientId), grams > 0 else { return nil }
        if let perGram = deal.weightPricePerGram { return perGram * grams }
        if let pack = deal.packGrams ?? deal.packCount.flatMap({ n in IngredientMatch.gramsPerUnit[swapType].map { Double(n) * $0 } }), pack > 0 {
            return (grams / pack).rounded(.up) * deal.effectivePrice
        }
        return nil
    }
}

extension Deal {

    /// Price per gram for flyer prices quoted per lb, kg or 100 g.
    nonisolated var weightPricePerGram: Double? {
        let label = unitLabel.lowercased().replacingOccurrences(of: " ", with: "")
        if label.contains("/lb") || label.contains("perlb") { return effectivePrice / 453.59237 }
        if label.contains("/kg") || label.contains("perkg") { return effectivePrice / 1_000 }
        if label.contains("/100g") { return effectivePrice / 100 }
        return nil
    }

    /// True when the price is for one item or one package, not for a weight.
    nonisolated var isPiecePriced: Bool { weightPricePerGram == nil }

    /// Package weight from the size text ("340g", "1,36 kg", "6 × 900 g"). A multipack is one purchase.
    nonisolated var packGrams: Double? {
        guard isPiecePriced else { return nil }
        return Self.packGrams(in: sizeText)
    }

    /// Number of pieces in a package ("12un", "Paquet de 6", "3 UN", "6 pk").
    nonisolated var packCount: Int? {
        guard isPiecePriced else { return nil }
        return Self.packCount(in: sizeText)
    }

    nonisolated static func packGrams(in sizeText: String?) -> Double? {
        guard let text = sizeText?.lowercased().replacingOccurrences(of: ",", with: ".") else { return nil }
        let multi = #"(\d+)\s*[x×]\s*(\d+(?:\.\d+)?)\s*(kg|g|lb|lbs)\b"#
        if let regex = try? NSRegularExpression(pattern: multi),
           let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let countRange = Range(m.range(at: 1), in: text),
           let numberRange = Range(m.range(at: 2), in: text),
           let unitRange = Range(m.range(at: 3), in: text),
           let count = Double(text[countRange]), let value = Double(text[numberRange]),
           let one = grams(value, unit: String(text[unitRange])) {
            return count * one
        }
        let pattern = #"(\d+(?:\.\d+)?)\s*(kg|g|lb|lbs)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numberRange = Range(m.range(at: 1), in: text), let unitRange = Range(m.range(at: 2), in: text),
              let value = Double(text[numberRange]) else { return nil }
        return grams(value, unit: String(text[unitRange]))
    }

    nonisolated static func packCount(in sizeText: String?) -> Int? {
        guard let text = sizeText?.lowercased() else { return nil }
        let patterns = [#"(\d+)\s*(un|unités?|units?|pk|pack|ct|count|ea)\b"#, #"(?:paquet|pack|sac|bag) de (\d+)"#]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let r = Range(m.range(at: 1), in: text), let n = Int(text[r]), n > 1, n < 60 else { continue }
            return n
        }
        return nil
    }

    private nonisolated static func grams(_ value: Double, unit: String) -> Double? {
        guard value > 0 else { return nil }
        switch unit {
        case "kg": return value * 1_000
        case "lb", "lbs": return value * 453.59237
        default: return value >= 20 ? value : nil
        }
    }
}
