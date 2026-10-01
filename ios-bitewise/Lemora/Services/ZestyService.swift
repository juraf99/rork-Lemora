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
    let remainingToday: Int?
    let model: String

    private enum CodingKeys: String, CodingKey {
        case message, recommendations, model
        case conversationId = "conversation_id"
        case followUpSuggestions = "follow_up_suggestions"
        case remainingToday = "remaining_today"
    }
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

private nonisolated struct ZestyContextSnapshot: Encodable, Sendable {
    let displayName: String?
    let profile: UserProfile
    let acceptedStoreIds: [String]
    let blockedStoreIds: [String]
    let savedRecipeIds: [String]
    let groceryItems: [ZestyGroceryContext]
    let recentCookedRecipeIds: [String]
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
    func ask(
        message: String,
        conversationId: String?,
        data: AppData,
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
            case "daily_safety_limit":
                friendly = server?.message ?? String(localized: "Zesty has reached today's limit. Please try again tomorrow.")
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
