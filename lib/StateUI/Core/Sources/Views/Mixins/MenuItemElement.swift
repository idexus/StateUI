// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every toolbar item and menu entry says - an action's or a
/// setting's: `text`, `icon`, `isEnabled` and `keyboardShortcut`.
///
/// Written on the item, in any order, before or after its own modifiers:
///
///     ToolbarButton("Delete")
///         .icon("trash.png")
///         .keyboardShortcut(.delete)
///         .onClicked { delete() }
public protocol MenuItemElement: AutomationElement {}

extension MenuItemElement {
    /// What the item says. Usually given in the initializer instead.
    public func text(_ value: String) -> Modified {
        setValue(MenuItemElementContract.text, value)
    }

    /// The picture on it, resolved from the application's image resources.
    public func icon(_ value: ImageSource) -> Modified {
        setValue(MenuItemElementContract.icon, value)
    }

    /// Whether it responds to selection. A disabled item stays visible, so the
    /// user still knows the action exists. An item declared in a disabled view
    /// is disabled with it.
    public func isEnabled(_ value: Bool) -> Modified {
        setValue(MenuItemElementContract.isEnabled, value)
    }

    /// Keys that choose it from the keyboard while its window is in front:
    /// `key` with `modifiers` - the platform's Command or Control unless said
    /// otherwise. A bar's item and a menu bar's entry are chosen by them; a
    /// context menu's entry shows them beside its words.
    ///
    ///     MenuItem("Save").keyboardShortcut("s")
    ///     ToolbarButton("Share").keyboardShortcut("s", modifiers: [.primary, .shift])
    public func keyboardShortcut(_ key: Key, modifiers: KeyModifiers = .primary) -> Modified {
        setValue(MenuItemElementContract.keyboardShortcut, KeyboardShortcut(key, modifiers: modifiers))
    }
}
