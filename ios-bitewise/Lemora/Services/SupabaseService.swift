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
    /// Fetches the catalogue and caches the raw response on the device. `changed` is false when the
    /// response is identical to the cached copy, so the app can keep its current cards untouched.
    func fetchRecipeCatalogue() async throws -> (recipes: [Recipe], changed: Bool) {
        let data = try await client
            .rpc("get_lemora_recipe_catalog")
            .execute()
            .data
        let rows = try JSONDecoder().decode([RemoteRecipeEnvelope].self, from: data)
        let recipes = rows.compactMap(\.recipe)
        let cacheURL = Self.recipeCatalogueCacheURL
        let changed = (try? Data(contentsOf: cacheURL)) != data
        if changed && !recipes.isEmpty { try? data.write(to: cacheURL, options: .atomic) }
        logger.info("Loaded \(recipes.count) recipes from the permanent catalogue (changed: \(changed))")
        return (recipes, changed)
    }

    nonisolated static var recipeCatalogueCacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lemora-recipe-catalogue-v1.json")
    }

    /// Recipes from the last successful download, available instantly at launch (empty if none).
    nonisolated static func cachedRecipeCatalogue() -> [Recipe] {
        guard let data = try? Data(contentsOf: recipeCatalogueCacheURL),
              let rows = try? JSONDecoder().decode([RemoteRecipeEnvelope].self, from: data) else { return [] }
        return rows.compactMap(\.recipe)
    }

    /// Loads current food-only flyer deals. The database view already excludes coupons,
    /// non-food items, stale flyers, and expired offers.
    func fetchActiveDeals(location: UserLocation) async throws -> [Deal] {
        let columns = "id,ingredient_id,product_name,retailer_product_name,brand,size_text,sale_price,regular_price,multi_buy_quantity,unit_label,provider_discount_percent,deal_score,deal_confidence,deal_label,food_category,dietary_flags,allergen_flags,image_url,source_postal_code,currency_code,valid_from,valid_until,region_codes,country_code,retailer_id,retailer_name,processing_level,health_priority_score,common_food_score,recommendation_score"
        guard location.isSet else {
            let rows: [LiveDealRow] = try await client
                .from("active_food_deals_unique")
                .select(columns)
                .order("deal_score", ascending: false)
                .limit(1_000)
                .execute()
                .value
            let active = Self.deduplicated(rows.compactMap(\.deal))
            logger.info("Loaded \(active.count) live weekly flyer deals without a location filter")
            return active
        }

        let countryCode = Self.normalizedCountryCode(location.countryCode)
        guard let country = SupportedCountry(rawValue: countryCode),
              let postal = country.normalizePostal(location.postalCode) else { return [] }
        await Self.ensureFlyerZone(postal)
        let rows: [LiveDealRow] = try await client
            .rpc("active_food_deals_for_postal", params: ["p_postal": postal])
            .execute()
            .value
        let local = Self.deduplicated(rows.compactMap { row in
            row.countryCode.uppercased() == countryCode ? row.deal : nil
        })
        logger.info("Loaded \(local.count) exact-postal weekly flyer deals for \(countryCode, privacy: .public)")
        return local
    }

    /// epiceries.ca currently documents a Quebec market, not Canada-wide or store-exact
    /// coverage. The postal RPC enforces that scope, and rejects US ZIP codes entirely.
    func fetchCurrentPrices(location: UserLocation) async throws -> [StorePrice] {
        guard location.isSet,
              Self.normalizedCountryCode(location.countryCode) == SupportedCountry.canada.code,
              let postal = SupportedCountry.canada.normalizePostal(location.postalCode) else { return [] }
        let rows: [LivePriceRow] = try await client
            .rpc("current_food_prices_for_postal", params: ["p_postal": postal])
            .execute()
            .value
        var best: [String: StorePrice] = [:]
        for price in rows.compactMap(\.price) {
            let key = "\(price.retailerId)|\(price.ingredientId)"
            if best[key].map({ price.currentPrice < $0.currentPrice }) ?? true { best[key] = price }
        }
        let prices = Array(best.values).sorted { $0.currentPrice < $1.currentPrice }
        logger.info("Loaded \(prices.count) fresh Quebec shelf prices for a Canadian postal code")
        return prices
    }

    /// The first time a postal code is seen, the backend looks up which weekly flyers cover it
    /// (a second or two). Later launches return immediately. Failures fall back to the nearest known zone.
    private static func ensureFlyerZone(_ postal: String) async {
        let cleaned = postal.uppercased().filter { $0.isLetter || $0.isNumber }
        guard let first = cleaned.first else { return }
        // Australia: Woolworths and Coles specials are national and loaded every Wednesday on the server.
        if cleaned.count == 4, cleaned.allSatisfy(\.isNumber) { return }
        // Quebec uses the weekly flyers. US ZIP codes and the rest of Canada use Instacart store prices
        // (the first visit of an area takes about 1 minute, then it is cached for 3 days).
        let instacart = first.isNumber || !"GHJ".contains(first)
        let name = instacart ? "instacart-us" : "flipp-direct-ingest"
        guard let url = URL(string: "\(LemoraBackend.projectURL.absoluteString)/functions/v1/\(name)") else { return }
        var request = URLRequest(url: url, timeoutInterval: instacart ? 100 : 8)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(LemoraBackend.publishableKey, forHTTPHeaderField: "apikey")
        let body: [String: String] = instacart ? (first.isNumber ? ["zip": String(cleaned.prefix(5))] : ["postal": cleaned]) : ["ensurePostal": postal]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }

    /// Final client-side safety net. Supabase already deduplicates the feed, but
    /// this guarantees that cached or temporarily inconsistent API data can never
    /// render two cards for the same ingredient at the same retailer.
    private static func deduplicated(_ deals: [Deal]) -> [Deal] {
        var bestByKey: [String: Deal] = [:]
        for deal in deals {
            let key = "\(deal.retailerId.lowercased())|\(deal.ingredientId.lowercased())|\(deal.productName.lowercased())"
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
        case "au", "aus", "australia", "australie": return "AU"
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
        let useFrench = AppLanguage.current == .fr
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

private nonisolated struct LivePriceRow: Decodable, Sendable {
    let id: String
    let ingredientId: String
    let productName: String
    let retailerProductName: String?
    let brand: String?
    let sizeText: String?
    let currentPrice: Double
    let regularPrice: Double?
    let salePrice: Double?
    let isDiscounted: Bool
    let unitLabel: String?
    let sourceUrl: String?
    let sourceUpdatedAt: String
    let staleAfter: String
    let retailerId: String
    let retailerName: String
    let foodCategory: String
    let dietaryFlags: [String: String]
    let allergenFlags: [String: String]
    let processingLevel: String
    let healthPriorityScore: Double
    let attribution: String
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ingredientId = "ingredient_id"
        case productName = "product_name"
        case retailerProductName = "retailer_product_name"
        case brand
        case sizeText = "size_text"
        case currentPrice = "current_price"
        case regularPrice = "regular_price"
        case salePrice = "sale_price"
        case isDiscounted = "is_discounted"
        case unitLabel = "unit_label"
        case sourceUrl = "source_url"
        case sourceUpdatedAt = "source_updated_at"
        case staleAfter = "stale_after"
        case retailerId = "retailer_id"
        case retailerName = "retailer_name"
        case foodCategory = "food_category"
        case dietaryFlags = "dietary_flags"
        case allergenFlags = "allergen_flags"
        case processingLevel = "processing_level"
        case healthPriorityScore = "health_priority_score"
        case attribution
        case imageUrl = "image_url"
    }

    var price: StorePrice? {
        guard currentPrice > 0,
              let updated = Self.date(sourceUpdatedAt),
              let stale = Self.date(staleAfter), stale >= .now else { return nil }
        let normalizedRetailer = retailerId.lowercased() == "super_c" ? "superc" : retailerId.lowercased()
        return StorePrice(
            id: id,
            ingredientId: ingredientId,
            productName: productName,
            retailerProductName: retailerProductName,
            retailerId: normalizedRetailer,
            retailerName: retailerName,
            currentPrice: currentPrice,
            regularPrice: regularPrice,
            salePrice: salePrice,
            isDiscounted: isDiscounted,
            unitLabel: unitLabel,
            sizeText: sizeText,
            brand: brand,
            sourceURL: sourceUrl.flatMap(URL.init(string:)),
            sourceUpdatedAt: updated,
            staleAfter: stale,
            category: GroceryCategory(rawValue: foodCategory) ?? .other,
            dietaryFlags: dietaryFlags,
            allergenFlags: allergenFlags,
            processingLevel: processingLevel,
            healthPriorityScore: healthPriorityScore,
            attribution: attribution,
            imageURL: imageUrl.flatMap(URL.init(string:))
        )
    }

    private static func date(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
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

        // Prices are kept in CAD inside the app (converted for display). US store prices arrive in USD.
        let toCAD = currencyCode.uppercased() == "USD" ? 1 / AppCurrency.usd.perCAD
            : currencyCode.uppercased() == "AUD" ? 1 / AppCurrency.aud.perCAD : 1
        RetailerCatalog.learn(Self.normalizedRetailerId(retailerId), retailerName)
        return Deal(
            id: id,
            ingredientId: ingredientId,
            retailerId: Self.normalizedRetailerId(retailerId),
            productName: productName,
            salePrice: salePrice * toCAD,
            regularPrice: regularPrice.map { $0 * toCAD },
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
            currencyCode: "CAD",
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
