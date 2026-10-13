import Foundation

/// Countries Lemora supports. Add a case (plus its stores) to expand to a new market.
nonisolated enum SupportedCountry: String, Codable, CaseIterable, Identifiable, Sendable {
    case canada = "CA"
    case unitedStates = "US"
    case australia = "AU"

    var id: String { rawValue }
    var code: String { rawValue }

    var title: String {
        switch self {
        case .canada: String(localized: "Canada")
        case .unitedStates: String(localized: "United States")
        case .australia: String(localized: "Australia")
        }
    }

    var flag: String {
        switch self {
        case .canada: "🇨🇦"
        case .unitedStates: "🇺🇸"
        case .australia: "🇦🇺"
        }
    }

    var currencyCode: String {
        switch self {
        case .canada: "CAD"
        case .unitedStates: "USD"
        case .australia: "AUD"
        }
    }

    var postalLabel: String {
        switch self {
        case .canada: String(localized: "Postal Code")
        case .unitedStates: String(localized: "ZIP Code")
        case .australia: String(localized: "Postcode")
        }
    }

    var postalPlaceholder: String {
        switch self {
        case .canada: "H2X 1Y4"
        case .unitedStates: "10001"
        case .australia: "2000"
        }
    }

    /// Normalizes user input ("h2x1y4" -> "H2X 1Y4") or returns nil when invalid.
    func normalizePostal(_ raw: String) -> String? {
        let cleaned = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        switch self {
        case .canada:
            let chars = Array(cleaned)
            guard chars.count == 6 else { return nil }
            let pattern: [Bool] = [true, false, true, false, true, false]
            for (c, isLetter) in zip(chars, pattern) where isLetter ? !c.isLetter : !c.isNumber { return nil }
            return String(chars[0..<3]) + " " + String(chars[3..<6])
        case .unitedStates:
            let digits = cleaned.prefix(5)
            guard digits.count == 5, digits.allSatisfy(\.isNumber) else { return nil }
            return String(digits)
        case .australia:
            guard cleaned.count == 4, cleaned.allSatisfy(\.isNumber) else { return nil }
            return cleaned
        }
    }

    /// Province / state code derived from a normalized postal code.
    func region(forPostal postal: String) -> String? {
        switch self {
        case .canada:
            guard let first = postal.first else { return nil }
            switch first {
            case "A": return "NL"
            case "B": return "NS"
            case "C": return "PE"
            case "E": return "NB"
            case "G", "H", "J": return "QC"
            case "K", "L", "M", "N", "P": return "ON"
            case "R": return "MB"
            case "S": return "SK"
            case "T": return "AB"
            case "V": return "BC"
            case "X": return "NT"
            case "Y": return "YT"
            default: return nil
            }
        case .unitedStates:
            guard let prefix = Int(postal.prefix(3)) else { return nil }
            return Self.usStateRanges.first { $0.range.contains(prefix) }?.state
        case .australia:
            // First digit of an Australian postcode -> state (ACT postcodes are 26xx / 29xx).
            if postal.hasPrefix("26") || postal.hasPrefix("29") { return "ACT" }
            switch postal.first {
            case "0": return "NT"
            case "1", "2": return "NSW"
            case "3", "8": return "VIC"
            case "4", "9": return "QLD"
            case "5": return "SA"
            case "6": return "WA"
            case "7": return "TAS"
            default: return nil
            }
        }
    }

    private static let usStateRanges: [(range: ClosedRange<Int>, state: String)] = [
        (10...27, "MA"), (28...29, "RI"), (30...38, "NH"), (39...49, "ME"), (50...59, "VT"), (60...69, "CT"),
        (70...89, "NJ"), (100...149, "NY"), (150...196, "PA"), (197...199, "DE"), (200...205, "DC"), (206...219, "MD"),
        (220...246, "VA"), (247...268, "WV"), (270...289, "NC"), (290...299, "SC"), (300...319, "GA"), (320...349, "FL"),
        (350...369, "AL"), (370...385, "TN"), (386...397, "MS"), (398...399, "GA"), (400...427, "KY"), (430...458, "OH"),
        (460...479, "IN"), (480...499, "MI"), (500...528, "IA"), (530...549, "WI"), (550...567, "MN"), (570...577, "SD"),
        (580...588, "ND"), (590...599, "MT"), (600...629, "IL"), (630...658, "MO"), (660...679, "KS"), (680...693, "NE"),
        (700...714, "LA"), (716...729, "AR"), (730...749, "OK"), (750...799, "TX"), (800...816, "CO"), (820...831, "WY"),
        (832...838, "ID"), (840...847, "UT"), (850...865, "AZ"), (870...884, "NM"), (885...885, "TX"), (889...898, "NV"),
        (900...961, "CA"), (967...968, "HI"), (970...979, "OR"), (980...994, "WA"), (995...999, "AK"),
    ]
}

/// UserLocation: where the user shops. Drives nearby chains, relevant deals and currency.
nonisolated struct UserLocation: Codable, Hashable, Sendable {
    enum Source: String, Codable, Sendable { case none, device, manual }

    var countryCode: String = ""
    /// Province or state code, e.g. "QC", "ON", "TX".
    var region: String?
    var postalCode: String = ""
    var city: String?
    var source: Source = .none

    var country: SupportedCountry? { SupportedCountry(rawValue: countryCode) }
    var isSet: Bool { country != nil && source != .none }
    var currencyCode: String { country?.currencyCode ?? "CAD" }

    static func manual(country: SupportedCountry, postalCode: String) -> UserLocation {
        let normalized = country.normalizePostal(postalCode) ?? postalCode.uppercased()
        return UserLocation(countryCode: country.code, region: country.region(forPostal: normalized),
                            postalCode: normalized, city: nil, source: .manual)
    }

    /// "Montréal, QC · H2X" style summary.
    var displayText: String {
        guard let country else { return String(localized: "Not set") }
        var parts: [String] = []
        if let city, !city.isEmpty { parts.append(city) }
        if let region { parts.append(region) }
        if parts.isEmpty { parts.append(country.title) }
        let place = parts.joined(separator: ", ")
        return postalCode.isEmpty ? place : "\(place) · \(postalCode.prefix(3))"
    }
}
