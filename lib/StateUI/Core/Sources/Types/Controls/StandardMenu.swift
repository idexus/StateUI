// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A menu the platform keeps on its menu bar, which a `Menu` joins by taking
/// it as its `.id`: the platform's own entries stay, and the menu's stand after
/// them as a section of their own.
///
///     .menuBar {
///         Menu("File") {
///             MenuItem("Export…").onClicked { export() }
///         }
///         .id(StandardMenu.file)
///     }
///
/// A menu joins by this identity, never by its caption, so a menu called
/// "Plik" joins the File menu too. Where the platform keeps no such menu, it
/// stands where that menu stands on the platform's bar.
public enum StandardMenu: Hashable, Sendable, CaseIterable, CustomStringConvertible {
    /// The menu of documents and windows: new, open, save, close.
    case file

    /// The menu of editing: undo, the clipboard, the selection.
    case edit

    /// The menu of how a window shows what it holds.
    case view

    /// The menu of the application's windows.
    case window

    /// The menu of help.
    case help

    /// The identity a menu takes with `.id(StandardMenu.file)`, apart from
    /// every identity an author writes.
    public var description: String {
        switch self {
        case .file: "StandardMenu.file"
        case .edit: "StandardMenu.edit"
        case .view: "StandardMenu.view"
        case .window: "StandardMenu.window"
        case .help: "StandardMenu.help"
        }
    }
}

@_spi(Host) extension StandardMenu {
    /// The standard menu an element's identity names; nil for any other.
    public init?(identity: String) {
        guard let named = Self.allCases.first(where: { $0.description == identity }) else { return nil }
        self = named
    }
}
