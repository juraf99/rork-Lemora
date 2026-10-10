import Foundation

nonisolated enum AnimalKind: String, Sendable {
    case none, meat, pork, poultry, fish, shellfish, dairy, egg, honey
}

/// Normalized ingredient in the Lemora ontology. `mayContain` captures uncertain allergens
/// (e.g. soy sauce -> wheat, curry paste -> shellfish). Uncertain is never treated as safe.
nonisolated struct Ingredient: Identifiable, Sendable {
    let id: String
    let name: String
    let category: GroceryCategory
    let contains: Set<Allergen>
    let mayContain: Set<Allergen>
    let animal: AnimalKind
}

nonisolated enum IngredientCatalog {
    private static func ing(_ id: String, _ name: String, _ category: GroceryCategory, contains: Set<Allergen> = [], may: Set<Allergen> = [], animal: AnimalKind = .none) -> Ingredient {
        Ingredient(id: id, name: name, category: category, contains: contains, mayContain: may, animal: animal)
    }

    static let all: [String: Ingredient] = {
        let list: [Ingredient] = [
            ing("chicken_breast", "Chicken breast", .protein, animal: .poultry),
            ing("flank_steak", "Flank steak", .protein, animal: .meat),
            ing("salmon", "Salmon fillet", .protein, contains: [.fish], animal: .fish),
            ing("eggs", "Eggs", .dairy, contains: [.egg], animal: .egg),
            ing("greek_yogurt", "Greek yogurt", .dairy, contains: [.milk], animal: .dairy),
            ing("sour_cream", "Sour cream", .dairy, contains: [.milk], animal: .dairy),
            ing("feta", "Feta", .dairy, contains: [.milk], animal: .dairy),
            ing("parmesan", "Parmesan", .dairy, contains: [.milk], animal: .dairy),
            ing("cream", "Cooking cream", .dairy, contains: [.milk], animal: .dairy),
            ing("protein_powder", "Whey protein", .pantry, contains: [.milk], animal: .dairy),
            ing("rice", "Rice", .pantry),
            ing("black_beans", "Black beans", .pantry),
            ing("chickpeas", "Chickpeas", .pantry),
            ing("lentils", "Lentils", .pantry),
            ing("rigatoni", "Rigatoni", .pantry, contains: [.wheat]),
            ing("oats", "Oats", .pantry, may: [.wheat]),
            ing("corn_tortillas", "Corn tortillas", .bakery, may: [.wheat]),
            ing("canned_tomatoes", "Crushed tomatoes", .pantry),
            ing("coconut_milk", "Coconut milk", .pantry),
            ing("curry_paste", "Curry paste", .pantry, may: [.shellfish]),
            ing("teriyaki_sauce", "Teriyaki sauce", .pantry, contains: [.soy, .wheat]),
            ing("soy_sauce", "Soy sauce", .pantry, contains: [.soy, .wheat]),
            ing("tahini", "Tahini", .pantry, contains: [.sesame]),
            ing("sesame_seeds", "Sesame seeds", .pantry, contains: [.sesame]),
            ing("maple_syrup", "Maple syrup", .pantry),
            ing("olive_oil", "Olive oil", .pantry),
            ing("pumpkin_seeds", "Pumpkin seeds", .pantry),
            ing("salsa_verde", "Salsa verde", .pantry),
            ing("corn", "Corn", .frozen),
            ing("edamame", "Edamame", .frozen, contains: [.soy]),
            ing("blueberries", "Blueberries", .produce),
            ing("avocado", "Avocado", .produce),
            ing("bell_pepper", "Bell peppers", .produce),
            ing("tomato", "Tomatoes", .produce),
            ing("onion", "Onion", .produce),
            ing("garlic", "Garlic", .produce),
            ing("lime", "Lime", .produce),
            ing("lemon", "Lemon", .produce),
            ing("cilantro", "Cilantro", .produce),
            ing("parsley", "Parsley", .produce),
            ing("basil", "Basil", .produce),
            ing("broccoli", "Broccoli", .produce),
            ing("carrot", "Carrots", .produce),
            ing("cucumber", "Cucumber", .produce),
            ing("cauliflower", "Cauliflower", .produce),
            ing("sweet_potato", "Sweet potato", .produce),
            ing("arugula", "Arugula", .produce),
            ing("spinach", "Spinach", .produce),
            ing("radish", "Radishes", .produce),
            ing("banana", "Bananas", .produce),
        ]
        return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }()

    static func ingredient(_ id: String) -> Ingredient? { all[id] }

    static func name(_ id: String) -> String {
        all[id]?.name ?? CatalogIngredientInfo.info[id]?.name ?? IngredientMatch.typeNames[id] ?? id.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func emoji(_ id: String) -> String {
        switch id {
        case "chicken_breast": "🍗"
        case "flank_steak": "🥩"
        case "salmon": "🐟"
        case "eggs": "🥚"
        case "greek_yogurt", "sour_cream", "cream": "🥛"
        case "feta", "parmesan": "🧀"
        case "rice": "🍚"
        case "black_beans", "chickpeas", "lentils", "edamame": "🫘"
        case "rigatoni": "🍝"
        case "oats": "🥣"
        case "corn_tortillas": "🌮"
        case "corn": "🌽"
        case "avocado": "🥑"
        case "bell_pepper": "🫑"
        case "tomato", "canned_tomatoes": "🍅"
        case "onion": "🧅"
        case "garlic": "🧄"
        case "lime", "lemon": "🍋"
        case "broccoli": "🥦"
        case "carrot": "🥕"
        case "cucumber": "🥒"
        case "sweet_potato": "🍠"
        case "blueberries": "🫐"
        case "banana": "🍌"
        case "coconut_milk": "🥥"
        case "cilantro", "parsley", "basil", "arugula", "spinach": "🌿"
        case "maple_syrup": "🍁"
        default: CatalogIngredientInfo.info[id]?.emoji ?? "🛒"
        }
    }
}
