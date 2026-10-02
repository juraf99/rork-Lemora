import Foundation
import ClerkKit

nonisolated struct ZestyNutrition: Codable, Hashable, Sendable {
    let calories: Double?
    let proteinG: Double?
    let carbsG: Double?
    let fiberG: Double?
    let sugarsG: Double?
    let fatG: Double?
    let saturatedFatG: Double?
    let sodiumMg: Double?
    let status: String
    let source: String?

    private enum CodingKeys: String, CodingKey {
        case calories, status, source
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fiberG = "fiber_g"
        case sugarsG = "sugars_g"
        case fatG = "fat_g"
        case saturatedFatG = "saturated_fat_g"
        case sodiumMg = "sodium_mg"
    }
}

nonisolated struct ZestyRecommendation: Codable, Hashable, Identifiable, Sendable {
    let title: String
    let subtitle: String?
    let estimatedCost: String?
    let retailer: String?
    let reason: String?
    let recipeId: String?
    let nutrition: ZestyNutrition?

    var id: String { recipeId ?? "\(title)|\(retailer ?? "")|\(reason ?? "")" }

    private enum CodingKeys: String, CodingKey {
        case title, subtitle, retailer, reason, nutrition
        case estimatedCost = "estimated_cost"
        case recipeId = "recipe_id"
    }
}

nonisolated struct ZestyAskResponse: Decodable, Sendable {
    let conversationId: String
    let message: String
    let recommendations: [ZestyRecommendation]
    let followUpSuggestions: [String]
    let remaining: Int?
    let allowanceTotal: Int?
    let accessPhase: String?
    let model: String

    private enum CodingKeys: String, CodingKey {
        case message, recommendations, model
        case conversationId = "conversation_id"
        case followUpSuggestions = "follow_up_suggestions"
        case remaining
        case allowanceTotal = "allowance_total"
        case accessPhase = "access_phase"
    }
}

nonisolated struct ZestyAllowance: Decodable, Sendable {
    let phase: String
    let remaining: Int
    let total: Int
}

nonisolated enum ZestyServiceError: LocalizedError, Sendable {
    case signInRequired
    case invalidResponse
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .signInRequired:
            String(localized: "Sign in so Zesty can securely use your Lemora profile.")
        case .invalidResponse:
            String(localized: "Zesty returned an incomplete response. Please try again.")
        case .server(let message):
            message
        }
    }
}

private nonisolated struct ZestyGroceryContext: Encodable, Sendable {
    let ingredientId: String
    let quantity: Double
    let unit: String
    let isChecked: Bool
    let estimatedCost: Double
}

private nonisolated struct ZestyAppRecipeIngredient: Encodable, Sendable {
    let ingredient_name: String
    let normalized_name: String
    let quantity: Double
    let unit: String
    let raw_text: String
}

private nonisolated struct ZestyAppRecipeStep: Encodable, Sendable {
    let step_number: Int
    let instruction: String
}

private nonisolated struct ZestyAppRecipeAllergen: Encodable, Sendable {
    let allergen_key: String
    let state: String
}

private nonisolated struct ZestyAppRecipeDiet: Encodable, Sendable {
    let diet: String
    let status: String
}

/// The catalogue visible in the installed app can differ from the published server catalogue.
/// Preserve its details for dialogue, while clearly identifying the bundled fixture estimates.
private nonisolated struct ZestyAppRecipeSnapshot: Encodable, Sendable {
    let id: String
    let name: String
    let description: String
    let servings: Int
    let prep_time_minutes: Int
    let cook_time_minutes: Int
    let cuisine: String
    let meal_type: String
    let recipe_ingredients: [ZestyAppRecipeIngredient]
    let recipe_steps: [ZestyAppRecipeStep]
    let recipe_nutrition: [ZestyNutrition]
    let recipe_allergens: [ZestyAppRecipeAllergen]
    let recipe_diet_compatibility: [ZestyAppRecipeDiet]
    let source_context = "bundled_app"
    let validation_status = "unverified_development_fixture"

    init(_ recipe: Recipe) {
        id = recipe.id
        name = recipe.title
        description = recipe.summary
        servings = recipe.servings
        prep_time_minutes = recipe.prepMinutes
        cook_time_minutes = recipe.cookMinutes
        cuisine = recipe.cuisine.rawValue
        meal_type = recipe.mealType.rawValue
        recipe_ingredients = recipe.ingredients.map {
            .init(ingredient_name: IngredientCatalog.name($0.ingredientId), normalized_name: $0.ingredientId,
                  quantity: $0.quantity, unit: $0.unit.rawValue, raw_text: $0.rawText)
        }
        recipe_steps = recipe.steps.enumerated().map { .init(step_number: $0.offset + 1, instruction: $0.element) }
        recipe_nutrition = [.init(
            calories: Double(recipe.nutrition.calories), proteinG: Double(recipe.nutrition.protein),
            carbsG: Double(recipe.nutrition.carbs), fiberG: recipe.nutrition.fiber.map(Double.init),
            sugarsG: nil, fatG: Double(recipe.nutrition.fat), saturatedFatG: nil, sodiumMg: nil,
            status: recipe.nutrition.status == .unknown ? "unknown" : "estimated",
            source: "Bundled Lemora development catalogue: estimates, not laboratory-verified. Missing values are unknown."
        )]
        let engine = RecommendationEngine()
        let allergens = engine.allergens(of: recipe)
        recipe_allergens = allergens.contains.map { .init(allergen_key: $0.databaseId, state: "contains") }
            + allergens.mayContain.map { .init(allergen_key: $0.databaseId, state: "may_contain") }
        recipe_diet_compatibility = engine.compatibility(of: recipe).map { diet, state in
            let key: String
            switch diet {
            case .glutenFree: key = "gluten_free"
            case .dairyFree: key = "dairy_free"
            case .highProtein: key = "high_protein"
            default: key = diet.rawValue.lowercased()
            }
            // Bundled ingredients are not proof of halal certification or cross-contamination safety.
            let certificationRequired = diet == .halal || diet == .glutenFree || diet == .dairyFree
            let status = state == .no ? "no" : (state == .uncertain || certificationRequired ? "unknown" : "yes")
            return .init(diet: key, status: status)
        }
    }
}

private nonisolated struct ZestyContextSnapshot: Encodable, Sendable {
    let displayName: String?
    let profile: UserProfile
    let acceptedStoreIds: [String]
    let blockedStoreIds: [String]
    let savedRecipeIds: [String]
    let groceryItems: [ZestyGroceryContext]
    let recentCookedRecipeIds: [String]
    let appRecipes: [ZestyAppRecipeSnapshot]
    let timeZone: String
}

private nonisolated struct ZestyAskRequest: Encodable, Sendable {
    let message: String
    let conversationId: String?
    let locale: String
    let context: ZestyContextSnapshot

    private enum CodingKeys: String, CodingKey {
        case message, locale, context
        case conversationId = "conversation_id"
    }
}

private nonisolated struct ZestyErrorResponse: Decodable, Sendable {
    let error: String?
    let message: String?
}

nonisolated struct ZestyService: Sendable {
    func allowance() async throws -> ZestyAllowance {
        guard let token = try? await Clerk.shared.auth.getToken(), !token.isEmpty else {
            throw ZestyServiceError.signInRequired
        }
        let endpoint = LemoraBackend.projectURL.appending(path: "functions")
            .appending(path: "v1").appending(path: "ask-zesty")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue(LemoraBackend.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (body, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ZestyServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let server = try? JSONDecoder().decode(ZestyErrorResponse.self, from: body)
            throw ZestyServiceError.server(message: server?.message ?? String(localized: "Zesty Ask is temporarily unavailable."))
        }
        return try JSONDecoder().decode(ZestyAllowance.self, from: body)
    }

    func ask(
        message: String,
        conversationId: String?,
        data: AppData,
        recipes: [Recipe],
        acceptedStoreIds: Set<String>,
        blockedStoreIds: Set<String>
    ) async throws -> ZestyAskResponse {
        guard let token = try? await Clerk.shared.auth.getToken(), !token.isEmpty else {
            throw ZestyServiceError.signInRequired
        }

        let endpoint = LemoraBackend.projectURL
            .appending(path: "functions")
            .appending(path: "v1")
            .appending(path: "ask-zesty")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(LemoraBackend.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let context = ZestyContextSnapshot(
            displayName: data.account?.name,
            profile: data.profile,
            acceptedStoreIds: acceptedStoreIds.sorted(),
            blockedStoreIds: blockedStoreIds.sorted(),
            savedRecipeIds: data.saved.map(\.recipeId),
            groceryItems: data.grocery.map {
                ZestyGroceryContext(
                    ingredientId: $0.ingredientId,
                    quantity: $0.quantity,
                    unit: $0.unit.rawValue,
                    isChecked: $0.isChecked,
                    estimatedCost: $0.estimatedCost
                )
            },
            recentCookedRecipeIds: data.cookLogs.sorted { $0.date > $1.date }.prefix(20).map(\.recipeId),
            appRecipes: recipes.map(ZestyAppRecipeSnapshot.init),
            timeZone: TimeZone.current.identifier
        )
        let payload = ZestyAskRequest(
            message: message,
            conversationId: conversationId,
            locale: Locale.current.language.languageCode?.identifier ?? "en",
            context: context
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)

        let (body, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ZestyServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let server = try? JSONDecoder().decode(ZestyErrorResponse.self, from: body)
            let friendly: String
            switch server?.error {
            case "unauthorized":
                friendly = String(localized: "Your session expired. Sign in again to talk with Zesty.")
            case "trial_total_limit", "daily_limit", "weekly_limit", "period_limit", "subscription_required":
                friendly = server?.message ?? String(localized: "Zesty Ask is temporarily unavailable.")
            case "zesty_not_configured":
                friendly = String(localized: "Zesty is being configured. Please try again shortly.")
            default:
                friendly = server?.message ?? String(localized: "Zesty couldn't finish that answer. Please try again.")
            }
            throw ZestyServiceError.server(message: friendly)
        }
        guard let result = try? JSONDecoder().decode(ZestyAskResponse.self, from: body) else {
            throw ZestyServiceError.invalidResponse
        }
        return result
    }
}
