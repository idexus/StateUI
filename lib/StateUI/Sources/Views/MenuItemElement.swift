// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a toolbar item, a menu entry and a swipe action all share: `text`,
/// `icon`, `isDestructive`, `isEnabled` - and `onClicked`, what
/// choosing one does.
///
/// Written on the item, in any order, before or after its own modifiers:
///
///     ToolbarItem("Delete")
///         .icon("trash.png")
///         .isDestructive(true)
///         .onClicked { delete() }
public protocol MenuItemElement: PropertyContainer {}

extension MenuItemElement {
    /// What the item says. Usually given in the initializer instead.
    public func text(_ value: String) -> Modified {
        setValue(MenuItemElementContract.text, value)
    }

    /// The picture on it, resolved from the application's image resources.
    public func icon(_ value: ImageSource) -> Modified {
        setValue(MenuItemElementContract.icon, value)
    }

    /// Whether the platform draws it as a destructive action. The look only: a
    /// confirmation is still the handler's to put up.
    public func isDestructive(_ value: Bool) -> Modified {
        setValue(MenuItemElementContract.isDestructive, value)
    }

    /// Whether it responds to selection. A disabled item stays visible, so the
    /// user still knows the action exists.
    public func isEnabled(_ value: Bool) -> Modified {
        setValue(MenuItemElementContract.isEnabled, value)
    }
}

extension MenuItemElement where Modified == Self {
    /// What it does - run when the item is chosen: clicked, tapped, or, for a
    /// swipe action under `.execute`, swiped all the way. A second
    /// `.onClicked` runs beside the first, like every typed event modifier.
    public func onClicked(_ handler: @escaping EventHandler) -> Self {
        modified { $0.addHandler(MenuItemElementContract.clicked.token, handler) }
    }
}
