// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The words StateUI says by itself - a dialog's own captions - in the system's language, as the platform's own
/// buttons are. Each language's words stand in its file under Languages.
/// Design: docs/design/types/localization.md#the-librarys-own-words
struct LibraryWords: LocalizedResources {
    typealias Catalog = LibraryCatalog

    let ok: String
    let cancel: String

    /// What a window's chrome says of its own controls: back, the sidebar, close and more.
    let chrome: ChromeWords

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

/// What a window's chrome says of its own controls, where the application names none - a back button, the sidebar's
/// toggle, a sheet's close, the overflow, the main menu - in the system's language.
@_spi(Host) public struct ChromeWords: Equatable, Sendable {
    /// A back button's, where the page below names none.
    public let back: String

    /// The sidebar's toggle.
    public let sidebar: String

    /// A sheet's or a window's close.
    public let close: String

    /// The overflow of a bar's actions.
    public let more: String

    /// The menu at a bar's end holding the page's menus, where a desktop shows no menu bar.
    public let mainMenu: String
}

/// The languages StateUI says its own words in, each by its tag.
enum LibraryLanguage: LocaleTag, CaseIterable {
    case english = "en"
    case polish = "pl"
}

/// StateUI's own languages, and the one it falls back to.
enum LibraryCatalog: LocalizationCatalog {
    static let defaultLanguage = LibraryLanguage.english
}
