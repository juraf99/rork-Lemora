import Foundation

/// Retailer registry for the Quebec market. Backend-driven in production; tier is UI organisation only.
nonisolated enum RetailerCatalog {
    private static func r(_ id: String, _ name: String, _ tier: RetailerTier, membership: Bool = false) -> Retailer {
        Retailer(id: id, name: name, tier: tier, membershipRequired: membership)
    }

    static let all: [Retailer] = [
        r("maxi", "Maxi", .featured), r("superc", "Super C", .featured), r("metro", "Metro", .featured),
        r("iga", "IGA", .featured), r("provigo", "Provigo", .featured), r("walmart", "Walmart", .featured),
        r("adonis", "Adonis", .featured), r("costco", "Costco", .featured, membership: true),
        r("mayrand", "Mayrand", .more), r("intermarche", "Intermarché", .more),
        r("tradition", "Les Marchés Tradition", .more), r("richelieu", "Marché Richelieu", .more),
        r("bonichoix", "Bonichoix", .more), r("pasquier", "Pasquier", .more), r("tnt", "T&T Supermarket", .more),
        r("pa", "Supermarché PA", .more), r("panature", "PA Nature", .more), r("kimphat", "Kim Phat", .more),
        r("rachelle", "Rachelle Béry", .more), r("avril", "Avril Supermarché Santé", .more),
        r("tau", "Marchés TAU", .more), r("tigre", "Tigre Géant", .more),
        r("aures", "Supermarché Aurès", .specialty), r("bonanza", "Bonanza Lalumière", .specialty),
        r("ct", "Marché C&T", .specialty), r("futai", "Marché Fu Tai", .specialty),
        r("btrust", "Btrust Supermarket", .specialty), r("liantai", "Lian Taï", .specialty),
        r("newon", "Marché Newon", .specialty), r("euro", "Euro Marché", .specialty),
        r("esposito", "Le Marché Esposito", .specialty),
    ]

    static let byId: [String: Retailer] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func name(_ id: String?) -> String {
        guard let id else { return String(localized: "Any store") }
        return byId[id]?.name ?? learnedNames.get(id) ?? id
    }

    /// Store names seen in live deals (US and Canada outside Quebec), so ids never show raw.
    private static let learnedNames = LearnedNames()
    static func learn(_ id: String, _ name: String) {
        guard byId[id] == nil, !name.isEmpty else { return }
        learnedNames.set(id, name)
    }
}

private final class LearnedNames: @unchecked Sendable {
    private let lock = NSLock()
    private var names: [String: String] = [:]
    func get(_ id: String) -> String? { lock.lock(); defer { lock.unlock() }; return names[id] }
    func set(_ id: String, _ name: String) { lock.lock(); names[id] = name; lock.unlock() }
}

/// SAMPLE promotions used until a licensed flyer provider or the manual flyer pipeline is connected.
/// Every deal here is flagged `isSampleData` and the UI labels them as sample prices.
nonisolated enum SampleDealProvider {
    static func deals(now: Date = .now) -> [Deal] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -2, to: now) ?? now
        let end = cal.date(byAdding: .day, value: 5, to: now) ?? now
        let expiredStart = cal.date(byAdding: .day, value: -9, to: now) ?? now
        let expiredEnd = cal.date(byAdding: .day, value: -1, to: now) ?? now

        func d(_ id: String, _ ing: String, _ store: String, _ name: String, _ sale: Double, _ regular: Double?, _ unit: String,
               multi: Int? = nil, label: DealLabel?, conf: DealConfidence, image: String?, cat: GroceryCategory,
               from: Date? = nil, until: Date? = nil) -> Deal {
            Deal(id: id, ingredientId: ing, retailerId: store, productName: name, salePrice: sale, regularPrice: regular,
                 unitLabel: unit, multiBuyQuantity: multi, validFrom: from ?? start, validUntil: until ?? end,
                 label: label, confidence: conf, imageName: image, category: cat, isSampleData: true)
        }

        return [
            d("d_chicken", "chicken_breast", "maxi", "Boneless chicken breast", 4.99, 8.99, "/lb", label: .rareDeal, conf: .high, image: "chicken_breasts_cutting_board", cat: .protein),
            d("d_yogurt", "greek_yogurt", "superc", "Plain Greek yogurt 750 g", 3.49, 5.99, "", label: .greatPrice, conf: .high, image: "greek_yogurt_bowl_spoon", cat: .dairy),
            d("d_pepper", "bell_pepper", "maxi", "Bell peppers", 4.00, 1.99, "", multi: 3, label: .goodPrice, conf: .medium, image: "bananas_peppers_avocados", cat: .produce),
            d("d_avocado", "avocado", "maxi", "Hass avocados", 5.00, 1.79, "", multi: 4, label: .goodPrice, conf: .medium, image: "bananas_peppers_avocados", cat: .produce),
            d("d_eggs", "eggs", "iga", "Large eggs, dozen", 3.99, 5.29, "", label: .greatPrice, conf: .high, image: "eggs_rice_carton", cat: .dairy),
            d("d_broccoli", "broccoli", "superc", "Broccoli crowns", 1.99, 3.49, "", label: .greatPrice, conf: .medium, image: nil, cat: .produce),
            d("d_rice", "rice", "adonis", "Basmati rice 8 kg", 8.99, 13.99, "", label: .goodPrice, conf: .medium, image: "eggs_rice_carton", cat: .pantry),
            d("d_salmon", "salmon", "metro", "Atlantic salmon fillets", 11.99, 14.99, "/lb", label: .goodPrice, conf: .medium, image: nil, cat: .protein),
            d("d_chickpeas", "chickpeas", "walmart", "Chickpeas 540 ml", 0.99, 1.79, "", label: .greatPrice, conf: .medium, image: nil, cat: .pantry),
            d("d_steak", "flank_steak", "provigo", "Flank steak", 12.99, 17.99, "/lb", label: .goodPrice, conf: .medium, image: nil, cat: .protein),
            d("d_sweetpotato", "sweet_potato", "kimphat", "Sweet potatoes", 0.99, 1.79, "/lb", label: .localDeal, conf: .medium, image: nil, cat: .produce),
            d("d_blueberries", "blueberries", "metro", "Blueberries 1 pint", 2.99, nil, "", label: nil, conf: .limitedHistory, image: nil, cat: .produce),
            d("d_rigatoni", "rigatoni", "costco", "Rigatoni 6 × 900 g", 11.99, 15.99, "", label: .goodPrice, conf: .medium, image: nil, cat: .pantry),
            // Expired on purpose: must never be shown as current.
            d("d_tomato_old", "tomato", "maxi", "Vine tomatoes", 0.99, 2.49, "/lb", label: .greatPrice, conf: .medium, image: nil, cat: .produce, from: expiredStart, until: expiredEnd),
        ]
    }
}
