import SwiftUI
import ObjectiveC

/// In-app language, independent of the iPhone language. Changing it rebuilds the app UI right away.
nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en, fr, es

    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .en: "English"
        case .fr: "Français"
        case .es: "Español"
        }
    }
    var flag: String {
        switch self {
        case .en: "🇺🇸"
        case .fr: "🇨🇦"
        case .es: "🇲🇽"
        }
    }
    var locale: Locale {
        let region = Locale.current.region?.identifier ?? "CA"
        return Locale(identifier: "\(rawValue)_\(region)")
    }

    private static let key = "lemoraAppLanguage"

    nonisolated static var current: AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: key), let language = AppLanguage(rawValue: saved) { return language }
        let system = String((Locale.preferredLanguages.first ?? "en").prefix(2))
        return AppLanguage(rawValue: system) ?? .en
    }

    @MainActor static func set(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: key)
        // Also used by iOS on the next launch (system texts, date formats).
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        LanguageBundle.install(language)
        LanguageState.shared.current = language
        // Recipes, recipe reasons and deal names are rebuilt in the new language.
        NotificationCenter.default.post(name: .lemoraLanguageChanged, object: nil)
    }

    @MainActor static func bootstrap() { LanguageBundle.install(current) }
}

extension Notification.Name {
    static let lemoraLanguageChanged = Notification.Name("lemoraLanguageChanged")
}

@Observable final class LanguageState {
    static let shared = LanguageState()
    var current: AppLanguage = AppLanguage.current
}

/// Looks up app texts in the chosen language only.
/// English is the source: the key itself. French and Spanish come from that language's table.
/// A missing translation stays in English. The iPhone language is never used as a fallback,
/// so choosing English cannot surface a French string.
nonisolated final class LanguageBundle: Bundle, @unchecked Sendable {
    nonisolated(unsafe) private static var language: AppLanguage = .en
    nonisolated(unsafe) private static var table: [String: String] = [:]
    nonisolated(unsafe) private static var target: Bundle?
    private static let swap: Void = { _ = object_setClass(Bundle.main, LanguageBundle.self) }()

    static func install(_ language: AppLanguage) {
        _ = swap
        Self.language = language
        table = [:]
        target = nil
        guard language != .en else { return }
        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language.rawValue),
           let dict = NSDictionary(contentsOf: url) as? [String: String] {
            table = dict
        }
        target = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap { Bundle(path: $0) }
    }

    override var preferredLocalizations: [String] { [Self.language.rawValue] }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if Self.language == .en { return key }
        if let translated = Self.table[key], !translated.isEmpty { return translated }
        if let target = Self.target {
            let found = target.localizedString(forKey: key, value: key, table: tableName)
            if !found.isEmpty, found != key { return found }
        }
        return key
    }
}

/// A plain text shown in the UI, in the in-app language when a translation exists.
nonisolated func lemoraLocalized(_ text: String) -> String {
    Bundle.main.localizedString(forKey: text, value: text, table: nil)
}

/// Compact language menu (onboarding first page).
struct LanguageMenu: View {
    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    AppLanguage.set(language)
                } label: {
                    if language == LanguageState.shared.current {
                        Label(language.nativeName, systemImage: "checkmark")
                    } else {
                        Text(verbatim: language.nativeName)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "globe")
                Text(verbatim: LanguageState.shared.current.rawValue.uppercased())
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.black.opacity(0.75))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.white.opacity(0.85), in: Capsule())
        }
        .accessibilityLabel(Text(verbatim: "Language / Langue / Idioma"))
    }
}
