import SwiftUI
import ObjectiveC

/// In-app language, independent of the iPhone language. Changing it rebuilds the app UI right away.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
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

    static func set(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: key)
        // Also used by iOS on the next launch (system texts, date formats).
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        LanguageBundle.install(language)
        LanguageState.shared.current = language
    }

    static func bootstrap() { LanguageBundle.install(current) }
}

@Observable final class LanguageState {
    static let shared = LanguageState()
    var current: AppLanguage = AppLanguage.current
}

/// Looks up app texts in the chosen language's table instead of the iPhone language.
nonisolated final class LanguageBundle: Bundle {
    nonisolated(unsafe) private static var target: Bundle?
    nonisolated(unsafe) private static var english = false
    private static let swap: Void = { _ = object_setClass(Bundle.main, LanguageBundle.self) }()

    static func install(_ language: AppLanguage) {
        _ = swap
        english = language == .en
        target = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap { Bundle(path: $0) }
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if tableName == nil || tableName == "Localizable" {
            if let target = Self.target { return target.localizedString(forKey: key, value: value, table: tableName) }
            if Self.english { return (value?.isEmpty == false ? value! : key) }
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

/// A plain text shown in the UI, in the in-app language when a translation exists.
/// Use this for `String` variables — `Text("literal")` already follows the SwiftUI locale.
nonisolated func lemoraLocalized(_ text: String) -> String {
    guard !text.isEmpty else { return text }
    var resource = LocalizedStringResource(stringLiteral: text)
    resource.locale = AppLanguage.current.locale
    return String(localized: resource)
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
