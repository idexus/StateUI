// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The words StateUI says by itself - a dialog's own captions, a control's own parts - in the system's language, as
/// the platform's own buttons are. Each language's words stand in its file under Languages.
/// Design: docs/design/types/localization.md#the-librarys-own-words
struct LibraryWords: LocalizedResources {
    typealias Catalog = LibraryCatalog

    let ok: String
    let cancel: String

    /// What a window's chrome says of its own controls: back, the sidebar, close and more.
    let chrome: ChromeWords

    /// What an Edit menu says of the entries a host keeps in it.
    let edit: EditWords

    /// What a control a host composes says of its own parts.
    let control: ControlWords

    /// What a menu bar a host keeps says of its own menus and entries.
    let menu: MenuWords

    /// What a file a host names itself is called.
    let file: FileWords

    /// What a question says on its own buttons.
    var question: QuestionWords { QuestionWords(accept: ok, cancel: cancel) }

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

/// What an Edit menu says of the entries a host keeps in it where its platform keeps no Edit menu of its own: the
/// field holding the keyboard undone, redone, cut, copied, pasted into, its selection deleted or the whole selected.
@_spi(Host) public struct EditWords: Equatable, Sendable {
    /// Undo.
    public let undo: String

    /// Redo.
    public let redo: String

    /// Cut.
    public let cut: String

    /// Copy.
    public let copy: String

    /// Paste.
    public let paste: String

    /// Delete.
    public let delete: String

    /// Select All.
    public let selectAll: String
}

/// What a menu bar a host keeps of its own says of its menus and their entries - File and a new window, Edit, Window
/// and its two entries, and quitting - in the system's language; Edit's entries are `EditWords`.
@_spi(Host) public struct MenuWords: Equatable, Sendable {
    /// File.
    public let file: String

    /// New Window.
    public let newWindow: String

    /// Edit.
    public let edit: String

    /// Window.
    public let window: String

    /// Minimize.
    public let minimize: String

    /// Bring All to Front.
    public let bringAllToFront: String

    /// Quit, before the application's name.
    public let quit: String
}

/// What a question for the user says on its own buttons where the application names none - the one accepting it and
/// the one cancelling it - in the system's language, as the platform's own buttons do.
@_spi(Host) public struct QuestionWords: Equatable, Sendable {
    /// The accepting button's caption: "OK".
    public let accept: String

    /// The cancelling button's caption: "Cancel".
    public let cancel: String
}

/// What a control a host composes itself, where its platform has none, says of its own parts to a screen reader - a
/// stepper's step down and step up, a map pin's button to its details - in the system's language.
@_spi(Host) public struct ControlWords: Equatable, Sendable {
    /// A step down.
    public let decrease: String

    /// A step up.
    public let increase: String

    /// The button opening what a pin tells of its place.
    public let details: String
}

/// What a file a host names itself is called, where the application names it nothing - a save written to a file
/// before the user places it.
@_spi(Host) public struct FileWords: Equatable, Sendable {
    /// A file named nothing.
    public let untitled: String
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
