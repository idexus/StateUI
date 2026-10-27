// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an item on a bar - a button, a setting, a group of them - shows of its own where its host draws the bar
/// itself, the Web's: the surface behind it, with `BorderElement`'s shape and outline, and how it looks under the
/// pointer. A bar that is the platform's keeps the platform's look.
///
///     ToolbarGroup { … }
///         .background(.white)
///         .shape(.roundedRectangle(12))
///         .stroke(.gray)
///         .visualState(.pointerOver) { $0.stroke(.accent) }
public protocol BarItemElement: PropertyContainer {}

extension BarItemElement {
    /// What the item's surface is made of: a color, a gradient, a blur of what lies behind it, or the platform's
    /// glass. An item's own background replaces its style's; a `Material(light:dark:)` follows the theme.
    public func background(_ value: Material) -> Modified { setValue(BarItemElementContract.background, value) }

    /// The item's background in one color; a `Color(light:dark:)` follows the theme.
    public func background(_ value: Color) -> Modified { background(.color(value)) }

    /// The item's background in a gradient.
    public func background(_ value: Brush) -> Modified { background(.gradient(value)) }
}

/// A button on a bar - an action or a setting: the user presses it, and its visual states follow.
///
///     ToolbarButton("Share")
///         .visualState(.pointerOver) { $0.background(.gray.opacity(0.12)) }
///         .visualState(.pressed) { $0.background(.gray.opacity(0.2)) }
public protocol BarButtonElement: BarItemElement {}
