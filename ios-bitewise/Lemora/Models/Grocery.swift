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
    case protein, produce, dairy, pantry, frozen, bakery

    var title: String {
        switch self {
        case .protein: String(localized: "Protein")
        case .produce: String(localized: "Produce")
        case .dairy: String(localized: "Dairy & eggs")
        case .pantry: String(localized: "Pantry")
        case .frozen: String(localized: "Frozen")
        case .bakery: String(localized: "Bakery")
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

    /// Effective per-item price for multi-buy offers ("3 for $4" -> $1.33).
    var effectivePrice: Double {
        guard let q = multiBuyQuantity, q > 1 else { return salePrice }
        return salePrice / Double(q)
    }

    /// Only computed when a real reference price exists.
    var discountPercent: Int? {
        guard let regular = regularPrice, regular > effectivePrice else { return nil }
        return Int(((1 - effectivePrice / regular) * 100).rounded())
    }

    var priceRatio: Double {
        guard let regular = regularPrice, regular > 0 else { return 1 }
        return min(1, effectivePrice / regular)
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
