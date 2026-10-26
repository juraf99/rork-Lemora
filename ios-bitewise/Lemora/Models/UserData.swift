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

nonisolated struct CookLog: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    let recipeId: String
    let date: Date
    let madeWithDeal: Bool
    let savings: Double
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
