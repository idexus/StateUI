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
public protocol MenuItemElement: AutomationElement, ShortcutElement {}

extension MenuItemElement {
    /// What the item says - what its initializer writes.
    func text(_ value: String) -> Modified {
        setValue(TextElementContract.text, value)
    }

    /// The picture on it, resolved from the application's image resources.
    public func icon(_ value: ImageSource) -> Modified {
        setValue(IconElementContract.icon, value)
    }

    /// Whether it responds to selection. A disabled item stays visible, so the
    /// user still knows the action exists. An item declared in a disabled view
    /// is disabled with it.
    public func isEnabled(_ value: Bool) -> Modified {
        setValue(EnabledElementContract.isEnabled, value)
    }
}
