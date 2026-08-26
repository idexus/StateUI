// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A caption, a picture and something to run - what MAUI's MenuItem is.
//
// Its own file, for the reason BarElement.swift gives. These are not views at
// all: a MenuItem is a BindableObject with no layout, so none of the tier in
// Elements.swift applies to one and none of this applies to a view.

/// The four properties a toolbar item, a menu entry and a swipe item all
/// share: `text`, `iconImageSource`, `isDestructive` and `isEnabled`.
/// MAUI: MenuItem - the class `ToolbarItem`, `MenuFlyoutItem` and `SwipeItem`
/// all derive from, and the one place MAUI declares the four.
///
/// Written on the item, in any order, before or after its own modifiers:
///
///     ToolbarItem("Delete")
///         .iconImageSource("trash.png")
///         .isDestructive(true)
///         .onClicked { delete() }
///
/// `MenuBarItem` is deliberately NOT one of these. MAUI derives it from
/// `BaseMenuItem` rather than `MenuItem` - a menu on the bar has a caption and
/// entries and is never clicked - so its `isEnabled` is its own property and
/// stays declared beside it.
///
/// `MenuFlyoutSubItem` is deliberately not one either, and this one is a
/// MEASUREMENT rather than a reading of MAUI: it does derive from `MenuItem`,
/// but `ApplyMenuEntry` in the renderer honours exactly `text` and `isEnabled`
/// on a submenu and nothing else. Conforming it would publish modifiers that
/// describe a property no host applies, which is the one failure this library
/// has no way to report.
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
    /// MAUI: MenuItem.Text.
    public func text(_ value: String) -> Modified {
        setValue(.text, .string(value))
    }

    /// The picture on it - a file in the app's Resources/Images, by the name
    /// MAUI gives it once built. MAUI: MenuItem.IconImageSource.
    public func iconImageSource(_ value: ImageSource) -> Modified {
        setValue(.iconImageSource, value.propValue)
    }

    /// Whether the platform draws it as a destructive action - red on Apple,
    /// so a delete looks like one. MAUI: MenuItem.IsDestructive.
    ///
    /// The LOOK only. It asks nothing and confirms nothing; a confirmation is
    /// still the handler's to put up.
    public func isDestructive(_ value: Bool) -> Modified {
        setValue(.isDestructive, .bool(value))
    }

    /// Whether it responds to a tap. A disabled item is still drawn, greyed
    /// out, which is what tells a reader the action exists at all.
    /// MAUI: MenuItem.IsEnabled.
    public func isEnabled(_ value: Bool) -> Modified {
        setValue(.isEnabled, .bool(value))
    }
}
