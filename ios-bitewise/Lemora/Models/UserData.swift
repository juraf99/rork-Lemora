import Foundation

nonisolated struct Account: Codable, Hashable, Sendable {
    var name: String
    var email: String
    var createdAt: Date
}

nonisolated struct UserProfile: Codable, Hashable, Sendable {
    var goal: Goal = .saveMoney
    var birthDate: Date?
    var usesMetric: Bool = true
    var heightCm: Double?
    var weightKg: Double?
    var goalWeightKg: Double?
    var diets: Set<DietPreference> = [.everything]
    var allergies: Set<Allergen> = []
    var customAllergies: [String] = []
    var dislikes: [String] = []
    var cuisines: Set<Cuisine> = []
    var weeklyBudget: Double? = 100
    var householdSize: Int = 1
    var storePreferences: [String: StorePreference] = [:]
    var shopsAtCostco: Bool = false
    var strategy: ShoppingStrategy = .balanced
    var maxStores: Int = 2
    var postalCode: String = ""
    var heardFrom: HeardFrom?
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
    var estimatedCost: Double
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

/// Everything persisted for the user. Local cache today; a backend sync layer plugs in via `UserDataSyncing`.
nonisolated struct AppData: Codable, Sendable {
    var schemaVersion: Int = 1
    var account: Account?
    var profile = UserProfile()
    var onboardingComplete = false
    var paywallSeen = false
    var notifications = NotificationPrefs()
    var premiumPreview = false
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
}
