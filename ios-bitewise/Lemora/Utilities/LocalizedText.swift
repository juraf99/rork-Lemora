import SwiftUI

// Every text shown in Lemora follows the language picked in the app (English, French or Spanish).
//
// SwiftUI only translates `Text("literal")`. A `Text(someString)` built from a variable is shown as is,
// so labels coming from catalogues and models stayed in English when French or Spanish was picked.
// This initializer (declared in the app, so it is used instead of SwiftUI's own for `Text(String)`)
// looks every string up in Localizable.xcstrings. Strings with no translation, such as recipe titles
// that are already translated or a person's name, are shown unchanged.
extension Text {
    nonisolated init<S: StringProtocol>(_ content: S) {
        self.init(verbatim: lemoraLocalized(String(content)))
    }
}

/// Formats dates and numbers in the language picked in the app, not the iPhone's language.
enum AppFormat {
    static var locale: Locale { AppLanguage.current.locale }

    /// "Monday", "lundi", "lunes".
    static func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).locale(locale))
    }

    /// "Oct 12", "12 oct.", "12 oct".
    static func monthDay(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().locale(locale))
    }

    /// "October 12", "12 octobre", "12 de octubre".
    static func longMonthDay(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day().locale(locale))
    }

    /// "October 12, 2026", "12 octobre 2026", "12 de octubre de 2026".
    static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.wide).day().locale(locale))
    }

    /// Joins a list the way each language does: "A, B and C", "A, B et C", "A, B y C".
    static func list(_ items: [String]) -> String {
        items.formatted(.list(type: .and).locale(locale))
    }
}
