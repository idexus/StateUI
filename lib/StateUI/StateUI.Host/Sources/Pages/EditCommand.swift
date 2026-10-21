// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What an Edit menu does to the field holding the keyboard, where a host keeps the menu's own entries - its
/// platform keeping no Edit menu of its own: each the toolkit's own act on the field.
/// Design: docs/design/host/pages.md#the-edit-menu
@_spi(Host) public enum EditCommand: Sendable, CaseIterable {
    /// Undoes the field's last change.
    case undo
    /// Does again what was undone.
    case redo
    /// Moves the selection to the clipboard.
    case cut
    /// Copies the selection to the clipboard.
    case copy
    /// Puts the clipboard's words in place of the selection.
    case paste
    /// Deletes the selection.
    case delete
    /// Selects the field's words whole.
    case selectAll

    /// The entries in the order every platform's Edit menu stands in, nil where a line parts undoing, the clipboard
    /// and the selection.
    static let menu: [EditCommand?] = [.undo, .redo, nil, .cut, .copy, .paste, .delete, nil, .selectAll]

    /// The entry's words.
    public func title(in words: EditWords) -> String {
        switch self {
        case .undo: words.undo
        case .redo: words.redo
        case .cut: words.cut
        case .copy: words.copy
        case .paste: words.paste
        case .delete: words.delete
        case .selectAll: words.selectAll
        }
    }

    /// The shortcut the entry shows beside its words - the field's own keys, which the field takes itself; `redo`
    /// as the platform spells Redo; none for Delete, whose key is written on it.
    func shortcut(redo: KeyboardShortcut) -> KeyboardShortcut? {
        switch self {
        case .undo: KeyboardShortcut("z")
        case .redo: redo
        case .cut: KeyboardShortcut("x")
        case .copy: KeyboardShortcut("c")
        case .paste: KeyboardShortcut("v")
        case .delete: nil
        case .selectAll: KeyboardShortcut("a")
        }
    }
}
