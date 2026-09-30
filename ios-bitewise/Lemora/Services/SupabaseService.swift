import Foundation
import OSLog
import Supabase

/// Shared entry point for the Lemora Supabase backend.
/// The publishable key is safe in a mobile client; access remains enforced by database RLS.
@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    static let projectReference = "fsucqlqsafoligouzgrl"
    private static let projectURL = URL(string: "https://fsucqlqsafoligouzgrl.supabase.co")!
    private static let publishableKey = "sb_publishable_2iPvFh4m-T-1oG-s84VOzw_1H4R9T3G"

    let client: SupabaseClient
    private let logger = Logger(subsystem: "app.lemora", category: "supabase")

    private init() {
        client = SupabaseClient(
            supabaseURL: Self.projectURL,
            supabaseKey: Self.publishableKey
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

    /// Loads current food-only flyer deals. The database view already excludes coupons,
    /// non-food items, stale flyers, and expired offers.
    func fetchActiveDeals(postalCode: String?) async throws -> [Deal] {
        let rows: [LiveDealRow] = try await client
            .from("active_food_deals_app")
            .select("id,ingredient_id,product_name,sale_price,regular_price,multi_buy_quantity,unit_label,provider_discount_percent,deal_score,deal_confidence,deal_label,food_category,dietary_flags,allergen_flags,image_url,source_postal_code,currency_code,valid_from,valid_until,retailer_id,retailer_name")
            .order("deal_score", ascending: false)
            .limit(1_000)
            .execute()
            .value

        let active = rows.compactMap(\.deal)
        guard let regionKey = Self.regionKey(postalCode) else {
            logger.info("Loaded \(active.count) live weekly flyer deals without a location filter")
            return active
        }

        let local = active.filter { Self.regionKey($0.sourcePostalCode) == regionKey }
        logger.info("Loaded \(local.count) live weekly flyer deals for region \(regionKey, privacy: .private)")
        return local
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
}

private nonisolated struct ConnectionProbe: Decodable, Sendable {
    let key: String
}

private nonisolated struct LiveDealRow: Decodable, Sendable {
    let id: String
    let ingredientId: String
    let productName: String
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
    let retailerId: String
    let retailerName: String

    enum CodingKeys: String, CodingKey {
        case id
        case ingredientId = "ingredient_id"
        case productName = "product_name"
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
        case retailerId = "retailer_id"
        case retailerName = "retailer_name"
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
            retailerId: retailerId,
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
            allergenFlags: allergenFlags
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
}
