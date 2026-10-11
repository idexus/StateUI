// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The words StateUI says by itself - a dialog's own captions - in the system's language, as the platform's own
/// buttons are. Each language's words stand in its file under Languages.
/// Design: docs/design/types/localization.md#the-librarys-own-words
struct LibraryWords: LocalizedResources {
    typealias Catalog = LibraryCatalog

    let ok: String
    let cancel: String

    static func resources(for language: LibraryLanguage) -> LibraryWords {
        switch language {
        case .english: .english
        case .polish: .polish
        }
    }

    /// The words in the first of the user's languages StateUI speaks; English where it speaks none.
    static var inSystemLanguage: LibraryWords {
        let preferences = Localization<LibraryCatalog>.preferences(of: StandardEnvironment.locale)
        return resources(for: Localization<LibraryCatalog>.matching(preferences) ?? LibraryCatalog.defaultLanguage)
    }
}

/// The languages StateUI says its own words in.
enum LibraryLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case polish = "pl"
}

/// StateUI's own languages, and the one it falls back to.
enum LibraryCatalog: LocalizationCatalog {
    static let defaultLanguage = LibraryLanguage.english
}
