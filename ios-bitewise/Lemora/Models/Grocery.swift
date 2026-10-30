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
    /// Exact retailer wording is kept for the detail screen; productName is canonical and brand-free.
    var retailerProductName: String? = nil
    var brand: String? = nil
    var sizeText: String? = nil
    var processingLevel: String = "unknown"
    var healthPriorityScore: Double = 50
    var commonFoodScore: Double = 40
    var recommendationScore: Double = 0

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

    /// Converts flyer unit prices to the quantity a recipe actually uses.
    /// Example: $0.79/lb for 700 g of chicken costs about $1.22, not $79 or $0.79 total.
    /// `gramsPerUnit` lets "2 tomatoes" be priced from a per-lb flyer; packages are prorated by their size.
    func cost(for quantity: Double, unit: IngredientUnit, useRegularPrice: Bool = false, gramsPerUnit: Double? = nil) -> Double? {
        let price: Double
        if useRegularPrice {
            guard let regularPrice else { return nil }
            price = regularPrice
        } else {
            price = effectivePrice
        }

        let label = unitLabel.lowercased().replacingOccurrences(of: " ", with: "")
        var perGram: Double? = nil
        if label.contains("/lb") || label.contains("perlb") || label.contains("/lbs") { perGram = price / 453.59237 }
        else if label.contains("/kg") || label.contains("perkg") { perGram = price / 1_000 }
        else if label.contains("/100g") { perGram = price / 100 }

        if unit == .g {
            if let perGram { return perGram * quantity }
            if let pack = packGrams, pack > 0 { return price * Self.packs(toCover: quantity, pack: pack) }
        }
        if unit == .ml, label.contains("/l") || label.contains("perlitre") || label.contains("perliter") {
            return price * quantity / 1_000
        }
        if unit == .unit {
            if let perGram {
                guard let gramsPerUnit else { return nil }
                return perGram * gramsPerUnit * quantity
            }
            // Buy whole packages. A 6-pack that is more than the recipe needs is paid in full,
            // so a bulk store does not look cheaper than a smaller pack that already covers the meal.
            if let count = packCount, count > 0 { return price * Self.packs(toCover: quantity, pack: Double(count)) }
            if let pack = packGrams, let gramsPerUnit, pack > 0 {
                return price * Self.packs(toCover: gramsPerUnit * quantity, pack: pack)
            }
            return price * max(1, quantity.rounded(.up))
        }
        if unit == .can {
            return price * max(1, quantity.rounded(.up))
        }
        return nil
    }

    /// How many packs you pay for. One pack is the smallest purchase that covers `needed`.
    private static func packs(toCover needed: Double, pack: Double) -> Double {
        guard needed > 0, pack > 0 else { return 1 }
        return max(1, (needed / pack).rounded(.up))
    }

    func isActive(at date: Date) -> Bool {
        date >= validFrom && date <= validUntil
    }
}

/// A current shelf-price observation. It becomes a `Deal` only when the provider
/// explicitly marks that observation as discounted.
nonisolated struct StorePrice: Identifiable, Hashable, Sendable {
    let id: String
    let ingredientId: String
    let productName: String
    let retailerProductName: String?
    let retailerId: String
    let retailerName: String
    let currentPrice: Double
    let regularPrice: Double?
    let salePrice: Double?
    let isDiscounted: Bool
    let unitLabel: String?
    let sizeText: String?
    let brand: String?
    let sourceURL: URL?
    let sourceUpdatedAt: Date
    let staleAfter: Date
    let category: GroceryCategory
    let dietaryFlags: [String: String]
    let allergenFlags: [String: String]
    let processingLevel: String
    let healthPriorityScore: Double
    let attribution: String
    var imageURL: URL? = nil

    var priceText: String {
        "\(Money.format(currentPrice))\(unitLabel.map { "/\($0)" } ?? "")"
    }

    /// Only provider-declared promotions become Steals. Ordinary shelf prices
    /// remain price observations and can never be presented as discounts.
    var promotionDeal: Deal? {
        // A market-price observation can remain useful as a comparison baseline
        // for 14 days, but it must not masquerade as this week's promotion. Flyer
        // deals use their exact validity dates through the dedicated feed.
        let weeklyPromotionCutoff = Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now
        guard isDiscounted,
              sourceUpdatedAt <= staleAfter,
              sourceUpdatedAt >= weeklyPromotionCutoff else { return nil }
        let displayUnit = unitLabel.flatMap { $0.isEmpty ? nil : "/\($0)" } ?? ""
        var deal = Deal(
            id: "price-promotion:\(id)",
            ingredientId: ingredientId,
            retailerId: retailerId,
            productName: productName,
            salePrice: salePrice ?? currentPrice,
            regularPrice: regularPrice,
            unitLabel: displayUnit,
            multiBuyQuantity: nil,
            validFrom: sourceUpdatedAt,
            validUntil: staleAfter,
            label: .localDeal,
            confidence: .uncertain,
            imageName: nil,
            category: category,
            isSampleData: false
        )
        deal.retailerName = retailerName
        deal.currencyCode = "CAD"
        deal.dietaryFlags = dietaryFlags
        deal.allergenFlags = allergenFlags
        deal.retailerProductName = retailerProductName
        deal.brand = brand
        deal.sizeText = sizeText
        deal.processingLevel = processingLevel
        deal.healthPriorityScore = healthPriorityScore
        deal.commonFoodScore = 50
        deal.recommendationScore = healthPriorityScore * 0.70 + 15
        return deal
    }

    func cost(for quantity: Double, unit: IngredientUnit) -> Double? {
        let label = unitLabel?.lowercased().replacingOccurrences(of: " ", with: "") ?? ""
        if unit == .g {
            if label == "lb" { return currentPrice * quantity / 453.59237 }
            if label == "kg" { return currentPrice * quantity / 1_000 }
            if label == "100g" { return currentPrice * quantity / 100 }
            if let pack = Deal.packGrams(in: sizeText), pack > 0 {
                return currentPrice * max(1, (quantity / pack).rounded(.up))
            }
        }
        if unit == .ml {
            if label == "l" { return currentPrice * quantity / 1_000 }
            if label == "100ml" { return currentPrice * quantity / 100 }
        }
        if unit == .unit || unit == .can {
            if let count = Deal.packCount(in: sizeText), count > 0 {
                return currentPrice * max(1, (quantity / Double(count)).rounded(.up))
            }
            return currentPrice * max(1, quantity.rounded(.up))
        }
        return nil
    }
}

// MARK: - Product names in the app language

/// Flyer product names arrive in the store's language ("Pilons de poulet frais", "Salmon Fillets").
/// They are shown in the language picked in the app: bilingual flyers ("FR | EN") are split, and a name
/// written in another language is replaced by the ingredient's name in the app language.
nonisolated enum ProductNaming {
    static func display(productName: String, retailerProductName: String?, ingredientId: String) -> String {
        let language = AppLanguage.current
        if let raw = retailerProductName, raw.contains(" | ") {
            let parts = raw.components(separatedBy: " | ").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                if language == .fr, !parts[0].isEmpty { return tidy(parts[0]) }
                if language == .en, !parts[1].isEmpty { return tidy(parts[1]) }
            }
        }
        if guessLanguage(productName) == language { return productName }
        let english = IngredientCatalog.name(ingredientId)
        if language == .en { return english }
        let translated = lemoraLocalized(english)
        return translated != english ? translated : productName
    }

    /// Rough language of a flyer name: accents or common French words mean French, Spanish words mean Spanish.
    static func guessLanguage(_ text: String) -> AppLanguage {
        let lower = text.lowercased()
        if lower.contains(where: { "àâçéèêëîïôûùüÿœ".contains($0) }) {
            return lower.contains(where: { "ñáíóú".contains($0) }) && !lower.contains(where: { "àâçèêëîïôûùœ".contains($0) }) ? .es : .fr
        }
        if lower.contains("ñ") { return .es }
        let words = Set(lower.split(whereSeparator: { !$0.isLetter }).map(String.init))
        let french: Set<String> = ["de", "du", "des", "au", "aux", "la", "le", "les", "et", "sans", "avec", "poulet", "boeuf", "porc",
                                   "frais", "fraiches", "fraises", "pommes", "pomme", "oignons", "tranches", "hache", "biologique",
                                   "biologiques", "lait", "fromage", "pain", "jambon", "saumon", "courge", "carottes", "poivrons",
                                   "laitue", "oeufs", "beurre", "farine", "riz", "pates", "sauce", "jus", "veau", "dinde", "crevettes",
                                   "haricots", "pois", "raisins", "poires", "citrons", "bleuets", "framboises", "mangues", "ananas"]
        let spanish: Set<String> = ["pollo", "carne", "res", "cerdo", "leche", "queso", "huevos", "con", "sin", "fresco", "frescos",
                                    "manzanas", "naranjas", "arroz", "frijoles", "tomates", "cebolla", "papas", "pan", "y", "del"]
        if !words.isDisjoint(with: french) { return .fr }
        if !words.isDisjoint(with: spanish) { return .es }
        return .en
    }

    /// "FILET DE TRUITE ARC-EN-CIEL, 300 G" -> "Filet de truite arc-en-ciel".
    static func tidy(_ text: String) -> String {
        var t = text
        if let comma = t.range(of: ",", options: .backwards), t[comma.upperBound...].contains(where: \.isNumber) {
            t = String(t[..<comma.lowerBound])
        }
        let letters = t.filter(\.isLetter)
        if !letters.isEmpty, letters == letters.uppercased() {
            let lower = t.lowercased()
            t = lower.prefix(1).uppercased() + lower.dropFirst()
        }
        return t.trimmingCharacters(in: .whitespaces)
    }
}

extension Deal {
    /// Product name in the language picked in the app.
    var displayName: String {
        ProductNaming.display(productName: productName, retailerProductName: retailerProductName, ingredientId: ingredientId)
    }
}

extension StorePrice {
    /// Product name in the language picked in the app.
    var displayName: String {
        ProductNaming.display(productName: retailerProductName ?? productName, retailerProductName: retailerProductName, ingredientId: ingredientId)
    }
}
