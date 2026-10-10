import Foundation
import OSLog
import Supabase

nonisolated enum LemoraBackend {
    static let projectReference = "fsucqlqsafoligouzgrl"
    static let projectURL = URL(string: "https://fsucqlqsafoligouzgrl.supabase.co")!
    static let publishableKey = "sb_publishable_2iPvFh4m-T-1oG-s84VOzw_1H4R9T3G"
}

/// Shared entry point for the Lemora Supabase backend.
/// The publishable key is safe in a mobile client; access remains enforced by database RLS.
@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    static let projectReference = LemoraBackend.projectReference

    let client: SupabaseClient
    private let logger = Logger(subsystem: "app.lemora", category: "supabase")
    private static let quebecPriorityBanners: Set<String> = [
        "maxi", "provigo", "iga", "metro", "super c", "walmart", "costco"
    ]

    private init() {
        client = SupabaseClient(
            supabaseURL: LemoraBackend.projectURL,
            supabaseKey: LemoraBackend.publishableKey
        )
    }

    /// Performs a small public read to verify that this build reaches the intended project.
    @discardableResult
    func verifyConnection() async -> Bool {
        do {
            let rows: [ConnectionProbe] = try await client
                .from("remote_config")
                .select("key")
                .limit(1)
                .execute()
                .value
            logger.info("Connected to Supabase project \(Self.projectReference, privacy: .public); probe rows=\(rows.count)")
            return true
        } catch {
            logger.error("Supabase connection failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Loads the permanent catalogue through a narrow read-only RPC. The complete
    /// bilingual source payload stays in Supabase so the client does not lose fields.
    func fetchRecipeCatalogue() async throws -> [Recipe] {
        let rows: [RemoteRecipeEnvelope] = try await client
            .rpc("get_lemora_recipe_catalog")
            .execute()
            .value
        let recipes = rows.compactMap(\.recipe)
        logger.info("Loaded \(recipes.count) recipes from the permanent catalogue")
        return recipes
    }

    /// Loads current food-only flyer deals. The database view already excludes coupons,
    /// non-food items, stale flyers, and expired offers.
    func fetchActiveDeals(location: UserLocation) async throws -> [Deal] {
        let rows: [LiveDealRow] = try await client
            .from("active_food_deals_unique")
            .select("id,ingredient_id,product_name,retailer_product_name,brand,size_text,sale_price,regular_price,multi_buy_quantity,unit_label,provider_discount_percent,deal_score,deal_confidence,deal_label,food_category,dietary_flags,allergen_flags,image_url,source_postal_code,currency_code,valid_from,valid_until,region_codes,country_code,retailer_id,retailer_name,processing_level,health_priority_score,common_food_score,recommendation_score")
            .order("deal_score", ascending: false)
            .limit(1_000)
            .execute()
            .value

        let priorityRows = rows.filter {
            Self.quebecPriorityBanners.contains($0.retailerName.lowercased())
        }
        let active = Self.deduplicated(priorityRows.compactMap(\.deal))
        guard location.isSet else {
            logger.info("Loaded \(active.count) live weekly flyer deals without a location filter")
            return active
        }

        let countryCode = Self.normalizedCountryCode(location.countryCode)
        let regionCode = Self.normalizedRegionCode(
            location.region,
            countryCode: countryCode,
            postalCode: location.postalCode
        )
        let postalRegion = Self.regionKey(location.postalCode)
        let local = Self.deduplicated(priorityRows.compactMap { row -> Deal? in
            guard let deal = row.deal, row.countryCode.uppercased() == countryCode else { return nil }
            if let regionCode, row.regionCodes.map({ $0.uppercased() }).contains(regionCode) { return deal }
            if let postalRegion, Self.regionKey(deal.sourcePostalCode) == postalRegion { return deal }
            return nil
        })
        logger.info("Loaded \(local.count) live weekly flyer deals for \(countryCode, privacy: .public)-\(regionCode ?? postalRegion ?? "unknown", privacy: .private)")
        return local
    }

    /// Final client-side safety net. Supabase already deduplicates the feed, but
    /// this guarantees that cached or temporarily inconsistent API data can never
    /// render two cards for the same ingredient at the same retailer.
    private static func deduplicated(_ deals: [Deal]) -> [Deal] {
        var bestByKey: [String: Deal] = [:]
        for deal in deals {
            let key = "\(deal.retailerId.lowercased())|\(deal.ingredientId.lowercased())"
            guard let existing = bestByKey[key] else {
                bestByKey[key] = deal
                continue
            }
            if deal.recommendationScore > existing.recommendationScore
                || (deal.recommendationScore == existing.recommendationScore
                    && deal.effectivePrice < existing.effectivePrice) {
                bestByKey[key] = deal
            }
        }
        return Array(bestByKey.values)
    }

    private static func regionKey(_ postalCode: String?) -> String? {
        let normalized = postalCode?
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        guard let normalized, !normalized.isEmpty else { return nil }
        if normalized.first?.isLetter == true, normalized.count >= 3 {
            return String(normalized.prefix(3)) // Canadian forward sortation area
        }
        if normalized.first?.isNumber == true, normalized.count >= 5 {
            return String(normalized.prefix(5)) // US ZIP code
        }
        return normalized
    }

    /// Profiles created by older builds may contain localized country/province names.
    /// Normalize them before matching the compact ISO codes stored by Supabase.
    private static func normalizedCountryCode(_ value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ca", "can", "canada": return "CA"
        case "us", "usa", "united states", "united states of america", "états-unis", "etats-unis": return "US"
        default: return value.uppercased()
        }
    }

    private static func normalizedRegionCode(
        _ value: String?,
        countryCode: String,
        postalCode: String
    ) -> String? {
        if countryCode == "CA",
           let derived = SupportedCountry.canada.region(forPostal: postalCode.uppercased()) {
            return derived
        }

        guard let value else { return nil }
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "qc", "quebec", "québec": return "QC"
        default: return value.uppercased()
        }
    }
}

private nonisolated struct RemoteRecipeEnvelope: Decodable, Sendable {
    let catalogueId: String
    let cataloguePayload: RemoteRecipePayload
    let imageUrl: String

    enum CodingKeys: String, CodingKey {
        case catalogueId = "catalogue_id"
        case cataloguePayload = "catalogue_payload"
        case imageUrl = "image_url"
    }

    var recipe: Recipe? {
        let payload = cataloguePayload
        guard !catalogueId.isEmpty, payload.servings > 0 else { return nil }
        let useFrench = Locale.current.identifier.lowercased().hasPrefix("fr")
        let ingredients = payload.ingredients.map { item in
            let name = useFrench ? item.name.fr : item.name.en
            let unit = Self.unit(item.unit)
            return RecipeIngredient(
                ingredientId: item.normalizedName,
                rawText: "\(unit.format(item.quantity)) \(name)",
                quantity: item.quantity,
                unit: unit,
                estimatedCost: item.estimatedCost
            )
        }
        let dietEntries = payload.dietClassification.filter {
            !["status", "criteria_version", "cross_contact"].contains($0.key)
        }
        let verified = Set(dietEntries.compactMap { $0.value == "yes" ? $0.key : nil })
        let rejected = Set(dietEntries.compactMap { $0.value == "no" ? $0.key : nil })
        let total = payload.totalMinutes ?? (payload.prepMinutes + payload.cookMinutes + (payload.restMinutes ?? 0))
        var tags = Set<RecipeTag>()
        if total <= 30 { tags.insert(.quick) }
        if verified.contains("high_protein") { tags.insert(.highProtein) }
        if verified.contains("vegetarian") { tags.insert(.vegetarianFriendly) }
        if payload.categories.contains(where: { $0.localizedCaseInsensitiveContains("meal prep") }) { tags.insert(.mealPrep) }
        if payload.categories.contains(where: { $0.localizedCaseInsensitiveContains("bowl") }) { tags.insert(.bowl) }

        return Recipe(
            id: catalogueId,
            title: useFrench ? payload.title.fr : payload.title.en,
            summary: useFrench ? (payload.description?.fr ?? "") : (payload.description?.en ?? ""),
            imageName: imageUrl,
            cuisine: Self.cuisine(payload.cuisine),
            mealType: Self.mealType(payload.mealType),
            mainProtein: payload.classification?.proteinSources.first ?? payload.ingredients.first?.normalizedName ?? "",
            servings: payload.servings,
            prepMinutes: payload.prepMinutes,
            cookMinutes: payload.cookMinutes + (payload.restMinutes ?? 0),
            ingredients: ingredients,
            steps: useFrench ? payload.instructions.fr : payload.instructions.en,
            nutrition: Nutrition(
                calories: payload.nutrition.calories,
                protein: payload.nutrition.protein,
                carbs: payload.nutrition.carbohydrates,
                fat: payload.nutrition.fat,
                fiber: payload.nutrition.fiber,
                status: NutritionStatus(rawValue: payload.nutrition.status) ?? .unknown
            ),
            tags: tags,
            source: payload.sourceType == "generated_suggestion" ? .generatedSuggestion : .external,
            verifiedDietKeys: verified,
            rejectedDietKeys: rejected,
            identifiedAllergenKeys: Set(payload.knownAllergens),
            possibleAllergenKeys: Set(payload.possibleAllergens),
            priceStatus: NutritionStatus(rawValue: payload.price?.status ?? "unknown") ?? .unknown,
            storePricesPerServing: payload.price?.byStore ?? [:]
        )
    }

    private static func unit(_ value: String) -> IngredientUnit {
        switch value.lowercased() {
        case "g", "gram", "grams": .g
        case "ml", "milliliter", "milliliters": .ml
        case "tbsp", "tablespoon", "tablespoons": .tbsp
        case "tsp", "teaspoon", "teaspoons": .tsp
        case "cup", "cups": .cup
        case "can", "cans": .can
        case "clove", "cloves": .clove
        default: .unit
        }
    }

    private static func mealType(_ value: String) -> MealType {
        switch value.lowercased() {
        case "breakfast": .breakfast
        case "lunch": .lunch
        case "snack": .snack
        case "dessert": .dessert
        default: .dinner
        }
    }

    private static func cuisine(_ value: String) -> Cuisine {
        let key = value.lowercased()
        if key.contains("ital") { return .italian }
        if key.contains("mex") { return .mexican }
        if key.contains("japan") { return .japanese }
        if key.contains("korean") { return .korean }
        if key.contains("india") { return .indian }
        if key.contains("greek") { return .greek }
        if key.contains("middle") || key.contains("levant") { return .middleEastern }
        if key.contains("french") { return .french }
        if key.contains("thai") { return .thai }
        if key.contains("vietnam") { return .vietnamese }
        if key.contains("caribbean") { return .caribbean }
        if key.contains("mediterr") { return .mediterranean }
        return .american
    }
}

private nonisolated struct RemoteRecipePayload: Decodable, Sendable {
    let sourceType: String
    let title: RemoteLocalizedText
    let description: RemoteLocalizedText?
    let mealType: String
    let cuisine: String
    let servings: Int
    let prepMinutes: Int
    let cookMinutes: Int
    let restMinutes: Int?
    let totalMinutes: Int?
    let categories: [String]
    let ingredients: [RemoteIngredient]
    let instructions: RemoteInstructions
    let knownAllergens: [String]
    let possibleAllergens: [String]
    let dietClassification: [String: String]
    let nutrition: RemoteNutrition
    let price: RemotePrice?
    let classification: RemoteClassification?

    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case title, description
        case mealType = "meal_type"
        case cuisine, servings
        case prepMinutes = "prep_minutes"
        case cookMinutes = "cook_minutes"
        case restMinutes = "rest_minutes"
        case totalMinutes = "total_minutes"
        case categories, ingredients, instructions
        case knownAllergens = "known_allergens"
        case possibleAllergens = "possible_allergens"
        case dietClassification = "diet_classification"
        case nutrition, price, classification
    }
}

private nonisolated struct RemoteLocalizedText: Decodable, Sendable { let fr: String; let en: String }
private nonisolated struct RemoteInstructions: Decodable, Sendable { let fr: [String]; let en: [String] }
private nonisolated struct RemoteIngredient: Decodable, Sendable {
    let normalizedName: String
    let name: RemoteLocalizedText
    let quantity: Double
    let unit: String
    let estimatedCost: Double?
    enum CodingKeys: String, CodingKey {
        case normalizedName = "normalized_name"
        case name, quantity, unit
        case estimatedCost = "estimated_cost"
    }
}
private nonisolated struct RemoteNutrition: Decodable, Sendable {
    let status: String
    let calories: Int?
    let protein: Int?
    let carbohydrates: Int?
    let fiber: Int?
    let fat: Int?
    enum CodingKeys: String, CodingKey {
        case status
        case calories = "calories_kcal"
        case protein = "protein_g"
        case carbohydrates = "carbohydrates_g"
        case fiber = "fiber_g"
        case fat = "fat_g"
    }
}
private nonisolated struct RemotePrice: Decodable, Sendable {
    let status: String?
    let perServing: Double?
    let byStore: [String: Double]?
    enum CodingKeys: String, CodingKey {
        case status
        case perServing = "per_serving"
        case byStore = "by_store_per_serving"
    }
}
private nonisolated struct RemoteClassification: Decodable, Sendable {
    let proteinSources: [String]
    enum CodingKeys: String, CodingKey { case proteinSources = "protein_sources" }
}

private nonisolated struct ConnectionProbe: Decodable, Sendable {
    let key: String
}

private nonisolated struct LiveDealRow: Decodable, Sendable {
    let id: String
    let ingredientId: String
    let productName: String
    let retailerProductName: String?
    let brand: String?
    let sizeText: String?
    let salePrice: Double
    let regularPrice: Double?
    let multiBuyQuantity: Int?
    let unitLabel: String
    let providerDiscountPercent: Double?
    let dealScore: Double?
    let dealConfidence: String?
    let dealLabel: String?
    let foodCategory: String
    let dietaryFlags: [String: String]
    let allergenFlags: [String: String]
    let imageUrl: String?
    let sourcePostalCode: String?
    let currencyCode: String
    let validFrom: String
    let validUntil: String
    let regionCodes: [String]
    let countryCode: String
    let retailerId: String
    let retailerName: String
    let processingLevel: String
    let healthPriorityScore: Double
    let commonFoodScore: Double
    let recommendationScore: Double

    enum CodingKeys: String, CodingKey {
        case id
        case ingredientId = "ingredient_id"
        case productName = "product_name"
        case retailerProductName = "retailer_product_name"
        case brand
        case sizeText = "size_text"
        case salePrice = "sale_price"
        case regularPrice = "regular_price"
        case multiBuyQuantity = "multi_buy_quantity"
        case unitLabel = "unit_label"
        case providerDiscountPercent = "provider_discount_percent"
        case dealScore = "deal_score"
        case dealConfidence = "deal_confidence"
        case dealLabel = "deal_label"
        case foodCategory = "food_category"
        case dietaryFlags = "dietary_flags"
        case allergenFlags = "allergen_flags"
        case imageUrl = "image_url"
        case sourcePostalCode = "source_postal_code"
        case currencyCode = "currency_code"
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case regionCodes = "region_codes"
        case countryCode = "country_code"
        case retailerId = "retailer_id"
        case retailerName = "retailer_name"
        case processingLevel = "processing_level"
        case healthPriorityScore = "health_priority_score"
        case commonFoodScore = "common_food_score"
        case recommendationScore = "recommendation_score"
    }

    var deal: Deal? {
        guard let start = Self.date(validFrom, endOfDay: false),
              let end = Self.date(validUntil, endOfDay: true),
              salePrice >= 0 else { return nil }

        let confidence: DealConfidence = switch dealConfidence {
        case "high": .high
        case "medium": .medium
        case "limited_history": .limitedHistory
        default: .uncertain
        }

        return Deal(
            id: id,
            ingredientId: ingredientId,
            retailerId: Self.normalizedRetailerId(retailerId),
            productName: productName,
            salePrice: salePrice,
            regularPrice: regularPrice,
            unitLabel: unitLabel,
            multiBuyQuantity: multiBuyQuantity,
            validFrom: start,
            validUntil: end,
            label: dealLabel.flatMap(DealLabel.init(rawValue:)),
            confidence: confidence,
            imageName: nil,
            category: GroceryCategory(rawValue: foodCategory) ?? .other,
            isSampleData: false,
            sourceDiscountPercent: providerDiscountPercent.map { Int($0.rounded()) },
            dealScore: dealScore ?? 0,
            imageURL: imageUrl.flatMap(URL.init(string:)),
            retailerName: retailerName,
            sourcePostalCode: sourcePostalCode,
            currencyCode: currencyCode,
            dietaryFlags: dietaryFlags,
            allergenFlags: allergenFlags,
            retailerProductName: retailerProductName,
            brand: brand,
            sizeText: sizeText,
            processingLevel: processingLevel,
            healthPriorityScore: healthPriorityScore,
            commonFoodScore: commonFoodScore,
            recommendationScore: recommendationScore
        )
    }

    private static func date(_ value: String, endOfDay: Bool) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto") ?? .current
        var components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        if endOfDay {
            components.hour = 23
            components.minute = 59
            components.second = 59
        }
        return calendar.date(from: components)
    }

    private static func normalizedRetailerId(_ value: String) -> String {
        switch value.lowercased() {
        case "super_c", "super-c", "super c": return "superc"
        default: return value.lowercased()
        }
    }
}
