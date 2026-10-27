import Foundation

nonisolated enum AuthProvider: String, Codable, Sendable {
    case apple, google, email, local
}

nonisolated struct Account: Codable, Hashable, Sendable {
    var name: String
    var email: String
    var createdAt: Date
    /// Backend (Clerk) user id. Nil for accounts created before the backend was connected.
    var userId: String?
    var provider: AuthProvider?
    /// True when this device created the account (new user) instead of signing in to an existing one.
    var isNewUser: Bool?
}

/// A normalized ingredient chosen by the user. `id` is the canonical ingredient-database id.
nonisolated struct IngredientRef: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
}

/// UserAllergies entry. Allergen ids come from the allergen database; ingredient ids from the
/// ingredient database (for rarer allergies). Never free text.
nonisolated struct AllergyRef: Codable, Hashable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable { case allergen, ingredient }
    let id: String
    let name: String
    let kind: Kind
}

/// Everything the user tells Lemora about themselves. Each concern stays in its own field:
/// goal, diets, allergies (safety), dislikes (taste), location, stores, budget, strategy, referral.
nonisolated struct UserProfile: Codable, Hashable, Sendable {
    var goal: Goal = .saveMoney
    /// Every goal the user picked (multi-select). `goal` stays the first one; empty on older profiles.
    var goals: Set<Goal> = []
    var birthDate: Date?
    var usesMetric: Bool = true
    var heightCm: Double?
    var weightKg: Double?
    var goalWeightKg: Double?
    var diets: Set<DietPreference> = []
    /// Explicit "No allergies" answer. Exclusive with `allergyRefs`.
    var hasNoAllergies: Bool = false
    var allergyRefs: [AllergyRef] = []
    var dislikedIngredients: [IngredientRef] = []
    var cuisines: Set<Cuisine> = []
    /// Kinds of recipes the user wants (breakfast, snacks…). Empty means all of them.
    var mealTypes: Set<MealType> = []
    /// Nil means "No strict budget".
    var weeklyBudget: Double? = 100
    var householdSize: Int = 1
    var storePreferences: [String: StorePreference] = [:]
    var shopsAtCostco: Bool = false
    var strategy: ShoppingStrategy = .balanced
    var maxStores: Int = 2
    var location = UserLocation()
    var referralSource: ReferralSource?

    init() {}

    var postalCode: String { location.postalCode }

    /// Primary goal first, then the other picked goals.
    var allGoals: [Goal] {
        [goal] + goals.filter { $0 != goal }.sorted { $0.rawValue < $1.rawValue }
    }

    /// Core allergen flags covered by the user's allergies (used against recipe ingredient flags).
    var allergies: Set<Allergen> {
        get {
            Set(allergyRefs.compactMap { ref in
                Allergen.allCases.first { $0.databaseId == ref.id || $0.rawValue == ref.id }
            })
        }
        set {
            allergyRefs = newValue.sorted { $0.rawValue < $1.rawValue }.map { flag in
                AllergyRef(id: flag.databaseId, name: flag.title, kind: .allergen)
            }
            if !allergyRefs.isEmpty { hasNoAllergies = false }
        }
    }

    var allergyNames: [String] { allergyRefs.map(\.name) }
    var dislikeNames: [String] { dislikedIngredients.map(\.name) }

    var acceptedStoreIds: [String] {
        storePreferences.filter { $0.value != .doNotRecommend }.map(\.key).sorted()
    }

    private enum LegacyKeys: String, CodingKey {
        case allergies, customAllergies, dislikes, heardFrom, postalCode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goal = try c.decodeIfPresent(Goal.self, forKey: .goal) ?? .saveMoney
        goals = (try? c.decodeIfPresent(Set<Goal>.self, forKey: .goals)) ?? []
        birthDate = try c.decodeIfPresent(Date.self, forKey: .birthDate)
        usesMetric = try c.decodeIfPresent(Bool.self, forKey: .usesMetric) ?? true
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm)
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
        goalWeightKg = try c.decodeIfPresent(Double.self, forKey: .goalWeightKg)
        diets = (try? c.decodeIfPresent(Set<DietPreference>.self, forKey: .diets)) ?? []
        hasNoAllergies = try c.decodeIfPresent(Bool.self, forKey: .hasNoAllergies) ?? false
        cuisines = (try? c.decodeIfPresent(Set<Cuisine>.self, forKey: .cuisines)) ?? []
        mealTypes = (try? c.decodeIfPresent(Set<MealType>.self, forKey: .mealTypes)) ?? []
        weeklyBudget = try c.decodeIfPresent(Double.self, forKey: .weeklyBudget)
        householdSize = try c.decodeIfPresent(Int.self, forKey: .householdSize) ?? 1
        storePreferences = try c.decodeIfPresent([String: StorePreference].self, forKey: .storePreferences) ?? [:]
        shopsAtCostco = try c.decodeIfPresent(Bool.self, forKey: .shopsAtCostco) ?? false
        strategy = try c.decodeIfPresent(ShoppingStrategy.self, forKey: .strategy) ?? .balanced
        maxStores = try c.decodeIfPresent(Int.self, forKey: .maxStores) ?? 2
        referralSource = try? c.decodeIfPresent(ReferralSource.self, forKey: .referralSource)

        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        if let refs = try c.decodeIfPresent([AllergyRef].self, forKey: .allergyRefs) {
            allergyRefs = refs
        } else if let old = try? legacy.decodeIfPresent(Set<Allergen>.self, forKey: .allergies) {
            allergies = old
        }
        if let items = try c.decodeIfPresent([IngredientRef].self, forKey: .dislikedIngredients) {
            dislikedIngredients = items
        } else if let old = try? legacy.decodeIfPresent([String].self, forKey: .dislikes) {
            dislikedIngredients = old.map { name in
                let match = IngredientCatalog.all.values.first {
                    $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
                }
                return IngredientRef(
                    id: match?.id ?? name.lowercased().replacingOccurrences(of: " ", with: "_"),
                    name: match?.name ?? name
                )
            }
        }
        if let loc = try c.decodeIfPresent(UserLocation.self, forKey: .location) {
            location = loc
        } else if let code = try? legacy.decodeIfPresent(String.self, forKey: .postalCode), !code.isEmpty {
            location = UserLocation.manual(country: .canada, postalCode: code)
        }
        if referralSource == nil, let old = try? legacy.decodeIfPresent(String.self, forKey: .heardFrom) {
            referralSource = ReferralSource(rawValue: old)
        }
    }
}

nonisolated struct NotificationPrefs: Codable, Hashable, Sendable {
    var dealAlerts = true
    var recommendations = true
    var priceDrops = true
    var weeklyRecap = true
}

nonisolated enum SwipeDirection: String, Codable, Sendable {
    case like, pass
}

nonisolated struct SwipeEvent: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    let recipeId: String
    let direction: SwipeDirection
    let timestamp: Date
    let engineVersion: String
    let positionInSession: Int
    let reasonCodes: [String]
    let wasCalibration: Bool
}

nonisolated struct SavedRecipe: Codable, Identifiable, Sendable {
    var id: String { recipeId }
    let recipeId: String
    let savedAt: Date
    var expiresAt: Date?
}

nonisolated struct GroceryItem: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    let ingredientId: String
    var quantity: Double
    let unit: IngredientUnit
    var recipeIds: [String]
    var isChecked: Bool = false
    var dealId: String?
    var retailerId: String?
    var estimatedCost: Double?
}

/// Something already at home. A matching grocery line stays off the list and is not added again.
nonisolated struct PantryStock: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var ingredientId: String?
    var name: String

    static func fold(_ text: String) -> String {
        text.replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "Œ", with: "oe")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func displayName(_ ingredientId: String) -> String {
        lemoraLocalized(IngredientCatalog.name(ingredientId))
    }

    static func covers(_ ingredientId: String, stocks: [PantryStock]) -> Bool {
        let keys = nameKeys(ingredientId)
        for stock in stocks {
            if stock.ingredientId == ingredientId { return true }
            if stock.ingredientId == nil, keys.contains(fold(stock.name)) { return true }
        }
        return false
    }

    /// Exact name in the current language, then a simple plural (`oignons` → `oignon`).
    static func matchingIngredientId(_ query: String) -> String? {
        let folded = fold(query)
        guard folded.count >= 2 else { return nil }
        let table = nameTable()
        if let id = table[folded] { return id }
        let singular = folded.hasSuffix("es") ? String(folded.dropLast(2)) : (folded.hasSuffix("s") ? String(folded.dropLast()) : folded)
        guard singular.count >= 3, singular != folded else { return nil }
        return table[singular]
    }

    private static func nameKeys(_ ingredientId: String) -> Set<String> {
        let english = IngredientCatalog.name(ingredientId)
        return [fold(english), fold(lemoraLocalized(english)), fold(ingredientId.replacingOccurrences(of: "_", with: " "))]
    }

    /// Ingredients of the Lemora catalogue that match what is typed, best first.
    /// Only these can be added to the pantry, so every item maps to a real ingredient.
    static func search(_ query: String, limit: Int = 6) -> [String] {
        let q = fold(query)
        guard q.count >= 2 else { return [] }
        var best: [String: (score: Double, id: String)] = [:]
        for (id, terms) in searchTerms() {
            var top: Double = 0
            for (index, term) in terms.enumerated() {
                var score: Double = 0
                if term == q { score = 120 }
                else if term.hasPrefix(q) { score = 100 - min(20, Double(term.count - q.count) * 0.6) }
                else if term.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "'" }).contains(where: { $0.hasPrefix(q) }) { score = 80 }
                else if term.contains(q) { score = 60 }
                else if q.count >= 3 && distance(q, String(term.prefix(q.count))) <= (q.count > 5 ? 2 : 1) { score = 40 }
                if index > 0 { score -= 4 }
                top = max(top, score)
            }
            guard top > 0 else { continue }
            // One row per name shown ("Bean sprouts" exists under two ids).
            let shown = fold(displayName(id))
            if let current = best[shown], current.score >= top { continue }
            best[shown] = (top, id)
        }
        return best.values
            .sorted { $0.score != $1.score ? $0.score > $1.score : displayName($0.id).count < displayName($1.id).count }
            .prefix(limit)
            .map { $0.id }
    }

    /// The catalogue ingredient whose name (in any language or synonym) is exactly what was typed.
    static func exactIngredientId(_ query: String) -> String? {
        if let id = matchingIngredientId(query) { return id }
        let q = fold(query)
        guard q.count >= 2 else { return nil }
        return searchTerms().first { $0.1.contains(q) }?.0
    }

    /// Name in the app language first, then English, the id and the onboarding synonyms (French names too).
    private static func searchTerms() -> [(String, [String])] {
        let extra = Dictionary(OBData.ingredients.map { ($0.id, [$0.en, $0.fr] + $0.syn) }, uniquingKeysWith: { a, _ in a })
        let ids = Set(IngredientCatalog.all.keys).union(CatalogIngredientInfo.info.keys)
        return ids.map { id in
            let english = IngredientCatalog.name(id)
            var terms = [fold(lemoraLocalized(english)), fold(english), fold(id.replacingOccurrences(of: "_", with: " "))]
            terms += (extra[id] ?? []).map(fold)
            var seen = Set<String>()
            return (id, terms.filter { !$0.isEmpty && seen.insert($0).inserted })
        }
    }

    private static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }

    private static func nameTable() -> [String: String] {
        var table: [String: String] = [:]
        let ids = Set(IngredientCatalog.all.keys).union(CatalogIngredientInfo.info.keys)
        for id in ids {
            let english = IngredientCatalog.name(id)
            table[fold(english)] = id
            table[fold(lemoraLocalized(english))] = id
        }
        return table
    }
}

nonisolated struct CookLog: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    let recipeId: String
    let date: Date
    let madeWithDeal: Bool
    let savings: Double
    /// Set when the meal was counted automatically from the week plan once its day was over.
    var planEntryId: UUID? = nil
}

nonisolated enum SavingsActionKind: String, Codable, Sendable {
    case cookedWithDeal, addedDealToList, markedMadeWithDeal
}

nonisolated struct SavingsAction: Codable, Sendable {
    let date: Date
    let kind: SavingsActionKind
}

/// OnboardingProgress: a guest's answers saved locally so they can resume after closing the app.
nonisolated struct OnboardingProgress: Codable, Sendable {
    var profile: UserProfile
    var stepId: String
    var updatedAt: Date
}

/// Everything persisted for the user. Local cache today; the account profile syncs to the backend.
nonisolated struct AppData: Codable, Sendable {
    var schemaVersion: Int = 2
    var account: Account?
    var profile = UserProfile()
    var onboardingComplete = false
    var paywallSeen = false
    var notifications = NotificationPrefs()
    var swipes: [SwipeEvent] = []
    var saved: [SavedRecipe] = []
    var grocery: [GroceryItem] = []
    /// Optional so lists saved before the pantry still open.
    var pantry: [PantryStock]?
    var cookLogs: [CookLog] = []
    var savingsActions: [SavingsAction] = []
    var activeDays: [String] = []
    var tasteWeights: [String: Double] = [:]
    var askUsage: [String: Int] = [:]
    var queueResetDate: Date?
    var welcomeSeen: Bool?
    var trialEndsAt: Date?
    var onboardingProgress: OnboardingProgress?
    var notificationPreference: NotificationPreference?
    var collections: [RecipeCollection]?
    var mealPlan: [MealPlanEntry]?
}

nonisolated struct MealPlanEntry: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    let recipeId: String
    let date: Date
    let mealType: MealSlot
}

nonisolated enum MealSlot: String, Codable, Sendable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner
    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MealSlot(rawValue: raw) ?? .dinner
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var label: String {
        switch self {
        case .breakfast: String(localized: "Breakfast")
        case .lunch: String(localized: "Lunch")
        case .dinner: String(localized: "Dinner")
        }
    }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        }
    }
}
