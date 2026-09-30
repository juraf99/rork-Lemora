import Foundation

nonisolated enum RetailerTier: String, Codable, Sendable {
    case featured, more, specialty
}

nonisolated struct Retailer: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let tier: RetailerTier
    let membershipRequired: Bool
}

nonisolated enum GroceryCategory: String, Codable, CaseIterable, Sendable {
    case protein, produce, dairy, pantry, frozen, bakery, beverages, prepared, snacks, other

    var title: String {
        switch self {
        case .protein: String(localized: "Protein")
        case .produce: String(localized: "Produce")
        case .dairy: String(localized: "Dairy & eggs")
        case .pantry: String(localized: "Pantry")
        case .frozen: String(localized: "Frozen")
        case .bakery: String(localized: "Bakery")
        case .beverages: String(localized: "Beverages")
        case .prepared: String(localized: "Prepared food")
        case .snacks: String(localized: "Snacks")
        case .other: String(localized: "Other food")
        }
    }

    var symbol: String {
        switch self {
        case .protein: "fish"
        case .produce: "carrot"
        case .dairy: "cup.and.saucer"
        case .pantry: "takeoutbag.and.cup.and.straw"
        case .frozen: "snowflake"
        case .bakery: "birthday.cake"
        case .beverages: "cup.and.saucer.fill"
        case .prepared: "takeoutbag.and.cup.and.straw.fill"
        case .snacks: "popcorn.fill"
        case .other: "basket.fill"
        }
    }
}

nonisolated enum DealLabel: String, Codable, Sendable {
    case rareDeal, greatPrice, goodPrice, localDeal

    var title: String {
        switch self {
        case .rareDeal: String(localized: "Rare deal")
        case .greatPrice: String(localized: "Great price")
        case .goodPrice: String(localized: "Good price")
        case .localDeal: String(localized: "Local deal")
        }
    }
}

nonisolated enum DealConfidence: String, Codable, Sendable {
    case high, medium, limitedHistory, uncertain

    var note: String {
        switch self {
        case .high: String(localized: "Compared with months of price history.")
        case .medium: String(localized: "Compared with recent prices.")
        case .limitedHistory: String(localized: "Limited price history so far.")
        case .uncertain: String(localized: "We couldn't verify the regular price.")
        }
    }
}

nonisolated struct Deal: Identifiable, Hashable, Sendable {
    let id: String
    let ingredientId: String
    let retailerId: String
    let productName: String
    let salePrice: Double
    let regularPrice: Double?
    let unitLabel: String
    let multiBuyQuantity: Int?
    let validFrom: Date
    let validUntil: Date
    let label: DealLabel?
    let confidence: DealConfidence
    let imageName: String?
    let category: GroceryCategory
    /// True for development fixtures. Never presented as live prices.
    let isSampleData: Bool
    /// Provider-reported flyer discount. Kept separate from a verified regular price.
    var sourceDiscountPercent: Int? = nil
    var dealScore: Double = 0
    var imageURL: URL? = nil
    var retailerName: String? = nil
    var sourcePostalCode: String? = nil
    var currencyCode: String = "CAD"
    var dietaryFlags: [String: String] = [:]
    var allergenFlags: [String: String] = [:]

    var retailerDisplayName: String {
        retailerName ?? RetailerCatalog.name(retailerId)
    }

    /// Effective per-item price for multi-buy offers ("3 for $4" -> $1.33).
    var effectivePrice: Double {
        guard let q = multiBuyQuantity, q > 1 else { return salePrice }
        return salePrice / Double(q)
    }

    /// Uses a verified regular price first, then the flyer provider's reported discount.
    var discountPercent: Int? {
        if let regular = regularPrice, regular > effectivePrice {
            return Int(((1 - effectivePrice / regular) * 100).rounded())
        }
        return sourceDiscountPercent
    }

    var priceRatio: Double {
        if let regular = regularPrice, regular > 0 {
            return min(1, effectivePrice / regular)
        }
        if let sourceDiscountPercent {
            return max(0, 1 - Double(sourceDiscountPercent) / 100)
        }
        return 1
    }

    var priceText: String {
        if let q = multiBuyQuantity, q > 1 {
            return String(localized: "\(q) for \(Money.format(salePrice))")
        }
        return "\(Money.format(salePrice))\(unitLabel)"
    }

    func isActive(at date: Date) -> Bool {
        date >= validFrom && date <= validUntil
    }
}
