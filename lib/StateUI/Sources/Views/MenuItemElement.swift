// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A caption, a picture and action presentation shared by item-like elements.
//
// Its own file, for the reason BarElement.swift gives. These are not views at
// all: none of the layout tier in Elements.swift applies to one and none of
// this applies to a view.

/// What a toolbar item, a menu entry and a swipe action all share: `text`,
/// `iconImageSource`, `isDestructive`, `isEnabled` - and `onClicked`, what
/// choosing one does.
///
/// Written on the item, in any order, before or after its own modifiers:
///
///     ToolbarItem("Delete")
///         .iconImageSource("trash.png")
///         .isDestructive(true)
///         .onClicked { delete() }
///
/// `Menu` deliberately stays outside this tier: a menu has a caption and
/// entries and is never clicked, so its `isEnabled` remains its own property
/// beside that structure, and an icon or a destructive look on it would
/// describe a capability the native host contract does not apply.
public protocol MenuItemElement: PropertyContainer {}

extension MenuItemElement {
    /// What the item says. Usually given in the initializer instead.
    public func text(_ value: String) -> Modified {
        setValue(.text, .string(value))
    }

    /// The picture on it, resolved from the application's image resources.
    public func iconImageSource(_ value: ImageSource) -> Modified {
        setValue(.iconImageSource, value.propValue)
    }

    /// Whether the platform draws it as a destructive action, so deletion and
    /// similarly irreversible choices look like what they do.
    ///
    /// The LOOK only. It asks nothing and confirms nothing; a confirmation is
    /// still the handler's to put up.
    public func isDestructive(_ value: Bool) -> Modified {
        setValue(.isDestructive, .bool(value))
    }

    /// Whether it responds to selection. A disabled item remains visible, so
    /// the reader still knows that the action exists.
    public func isEnabled(_ value: Bool) -> Modified {
        setValue(.isEnabled, .bool(value))
    }
}

extension MenuItemElement where Modified == Self {
    /// What it does - run when the item is chosen: clicked, tapped, or, for a
    /// swipe action under `.execute`, swiped all the way. A second
    /// `.onClicked` runs beside the first, like every typed event modifier.
    public func onClicked(_ handler: @escaping EventHandler) -> Self {
        modified { $0.addHandler(.clicked, handler) }
    }
}
