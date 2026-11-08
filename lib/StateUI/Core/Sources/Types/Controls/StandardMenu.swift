// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A menu the platform keeps on its menu bar, which a `Menu` joins with
/// `.joins(_:)`: the platform's own entries stay, and the menu's stand after
/// them as a section of their own.
///
///     .menuBar {
///         Menu("File") {
///             MenuItem("Export…").onClicked { export() }
///         }
///         .joins(.file)
///     }
///
/// A menu joins by this, never by its caption, so a menu called
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

    /// The menu's name in diagnostics. Its typed role is distinct from every string an author writes.
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
