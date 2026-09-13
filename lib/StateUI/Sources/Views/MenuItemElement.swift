// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A caption, a picture and action presentation shared by item-like elements.
//
// Its own file, for the reason BarElement.swift gives. These are not views at
// all: none of the layout tier in Elements.swift applies to one and none of
// this applies to a view.

/// The four properties a toolbar item, a menu entry and a swipe item all
/// share: `text`, `iconImageSource`, `isDestructive` and `isEnabled`.
///
/// Written on the item, in any order, before or after its own modifiers:
///
///     ToolbarItem("Delete")
///         .iconImageSource("trash.png")
///         .isDestructive(true)
///         .onClicked { delete() }
///
/// `MenuBarItem` deliberately stays outside this tier: a menu on the bar has a
/// caption and entries and is never clicked, so its `isEnabled` remains its own
/// property beside that structure.
///
/// `MenuFlyoutSubItem` deliberately stays outside it too. A submenu has text,
/// enabled state, and nested entries; publishing icon or destructive policy on
/// it would describe a capability the native host contract does not apply.
///
/// `Clicked` IS a MenuItem event and is deliberately NOT here, for the same
/// measured reason: a `SwipeItem` is answered by `Invoked`, which is the event
/// the renderer subscribes on one and the only one a swipe raises. So
/// `onClicked` stays written on the two items that raise it. Four modifiers
/// shared and one copied twice is the honest split; putting the fifth here
/// would give a swipe item a handler nothing ever calls.
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
