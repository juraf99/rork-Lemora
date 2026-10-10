import SwiftUI

/// Currencies Lemora can display. Recipe and deal prices are stored in CAD and converted for display.
nonisolated enum AppCurrency: String, CaseIterable, Identifiable, Sendable {
    case cad = "CAD", usd = "USD", eur = "EUR", gbp = "GBP", chf = "CHF", mxn = "MXN", aud = "AUD"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cad: String(localized: "Canadian dollar")
        case .usd: String(localized: "US dollar")
        case .eur: String(localized: "Euro")
        case .gbp: String(localized: "British pound")
        case .chf: String(localized: "Swiss franc")
        case .mxn: String(localized: "Mexican peso")
        case .aud: String(localized: "Australian dollar")
        }
    }

    var flag: String {
        switch self {
        case .cad: "🇨🇦"
        case .usd: "🇺🇸"
        case .eur: "🇪🇺"
        case .gbp: "🇬🇧"
        case .chf: "🇨🇭"
        case .mxn: "🇲🇽"
        case .aud: "🇦🇺"
        }
    }

    /// Approximate value of 1 CAD in this currency (display conversion only).
    var perCAD: Double {
        switch self {
        case .cad: 1
        case .usd: 0.72
        case .eur: 0.62
        case .gbp: 0.54
        case .chf: 0.58
        case .mxn: 13.2
        case .aud: 1.10
        }
    }

    /// Local convention: "4,27 $" in Canada, "$4.27" in the US, "4,27 €" in France.
    func format(cad value: Double) -> String {
        let amount = value * perCAD
        let number = amount.formatted(.number.precision(.fractionLength(2)))
        switch self {
        case .cad: return "\(number) $"
        case .usd, .mxn, .aud: return "$\(number)"
        case .eur: return "\(number) €"
        case .gbp: return "£\(number)"
        case .chf: return "\(number) CHF"
        }
    }

    private static let euroCountries: Set<String> = [
        "FR", "BE", "LU", "DE", "AT", "IT", "ES", "PT", "NL", "IE", "FI", "GR", "SK", "SI", "EE", "LV", "LT",
        "MT", "CY", "HR", "MC", "AD", "SM", "VA", "RE", "GP", "MQ", "GF", "YT", "PM", "BL", "MF",
    ]

    static func forCountry(_ code: String) -> AppCurrency? {
        let c = code.uppercased()
        switch c {
        case "CA": return .cad
        case "US", "PR": return .usd
        case "GB", "UK": return .gbp
        case "CH", "LI": return .chf
        case "MX": return .mxn
        case "AU": return .aud
        default: return euroCountries.contains(c) ? .eur : nil
        }
    }

    /// Country from the location entered at onboarding, then the postal code shape, then the phone region.
    static func automatic(countryCode: String, postalCode: String) -> AppCurrency {
        if let c = forCountry(countryCode) { return c }
        let cleaned = postalCode.uppercased().filter { $0.isLetter || $0.isNumber }
        if cleaned.count == 6, cleaned.first?.isLetter == true { return .cad }
        if cleaned.count == 5, cleaned.allSatisfy(\.isNumber) { return .usd }
        if let region = Locale.current.region?.identifier, let c = forCountry(region) { return c }
        return .cad
    }
}

/// Observable so every price on screen refreshes when the currency changes.
@Observable
nonisolated final class CurrencyState: @unchecked Sendable {
    static let shared = CurrencyState()
    private static let overrideKey = "lemora.currencyOverride"

    private(set) var current: AppCurrency
    private(set) var automatic: AppCurrency = .cad

    /// nil = automatic (from location). Saved on the device.
    var override: AppCurrency? {
        didSet {
            UserDefaults.standard.set(override?.rawValue, forKey: Self.overrideKey)
            current = override ?? automatic
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.overrideKey).flatMap(AppCurrency.init(rawValue:))
        override = saved
        current = saved ?? .cad
    }

    func sync(countryCode: String, postalCode: String) {
        let auto = AppCurrency.automatic(countryCode: countryCode, postalCode: postalCode)
        if automatic != auto { automatic = auto }
        let resolved = override ?? auto
        if current != resolved { current = resolved }
    }
}

/// Profile > Currency.
struct CurrencyEditView: View {
    @Environment(AppStore.self) private var store
    private var state: CurrencyState { CurrencyState.shared }

    var body: some View {
        List {
            Section {
                Button {
                    store.setCurrency(nil)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatic").font(.bw(.body, weight: .semibold)).foregroundStyle(BW.ink)
                            Text("From your location · \(state.automatic.flag) \(state.automatic.rawValue)")
                                .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                        }
                        Spacer()
                        if state.override == nil { Image(systemName: "checkmark").foregroundStyle(BW.leafDeep).fontWeight(.bold) }
                    }
                }
            }
            Section {
                ForEach(AppCurrency.allCases) { c in
                    Button {
                        store.setCurrency(c)
                    } label: {
                        HStack(spacing: 12) {
                            Text(c.flag).font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(.bw(.body, weight: .semibold)).foregroundStyle(BW.ink)
                                Text("\(c.rawValue) · \(c.format(cad: 10))").font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                            }
                            Spacer()
                            if state.override == c { Image(systemName: "checkmark").foregroundStyle(BW.leafDeep).fontWeight(.bold) }
                        }
                    }
                }
            } footer: {
                Text("Grocery prices are estimated in Canadian dollars and converted with approximate exchange rates.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(BW.canvas)
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
    }
}
