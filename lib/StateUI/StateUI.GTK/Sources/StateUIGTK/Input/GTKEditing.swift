// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import CStateUIGTK

/// The Edit menu's own entries as GTK does them: each the text widget's own action - its history, its clipboard, its
/// selection - on the widget the user last typed into in the window, which takes the focus back.
/// Design: docs/design/platforms/gtk/pages.md#the-edit-menu
@MainActor
enum GTKEditing {
    /// Does `command` to the widget the user last typed into in `window`; nothing where none stands.
    static func perform(_ command: EditCommand, in window: GTKWindow?) {
        guard let typed = window?.typed else { return }
        gtk_widget_grab_focus(typed)
        _ = gtk_widget_activate_action_variant(typed, action(command), nil)
    }

    /// The text widget's own action doing `command`.
    static func action(_ command: EditCommand) -> String {
        switch command {
        case .undo: "text.undo"
        case .redo: "text.redo"
        case .cut: "clipboard.cut"
        case .copy: "clipboard.copy"
        case .paste: "clipboard.paste"
        case .delete: "selection.delete"
        case .selectAll: "selection.select-all"
        }
    }
}
