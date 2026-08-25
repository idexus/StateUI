// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: Rectangle.

/// A rectangle, drawn as a shape. MAUI: Rectangle.
///
///     Rectangle()
///         .fill(.cornflowerBlue)
///         .radiusX(8)
///         .radiusY(8)
///         .heightRequest(60)
///
/// A `BoxView` says the same thing in one line and takes one colour; this is the
/// shape, so it takes a Brush, an outline and everything else the shape tier
/// declares.
///
/// It has no size of its own: give it a `heightRequest`, a `widthRequest` or a
/// layout that stretches it, or it draws nothing.
public struct Rectangle: Shape, RectangleProperties {
    /// The node this control describes.
    public var node: Node

    /// A rectangle with nothing set - which is also what a `Style<Rectangle>` is
    /// written against.
    public init() {
        node = Node(type: .rectangle)
    }
}

/// Rectangle's own properties - the half a `Style<Rectangle>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol RectangleProperties: PropertyContainer {}

extension RectangleProperties {
    /// How far the corners are rounded ACROSS, in device units. 0 - the
    /// default - is a square corner. MAUI: Rectangle.RadiusX.
    ///
    /// A corner is rounded by the two radii together, so write `radiusY`
    /// beside it - the same number for a circular corner.
    public func radiusX(_ value: Double) -> Modified { setValue(.radiusX, .number(value)) }

    /// And DOWN. MAUI: Rectangle.RadiusY. Equal to `radiusX` for a circular
    /// corner; different for an elliptical one.
    ///
    /// Both radii round ALL FOUR corners the same way. `RoundRectangle` is the
    /// shape that names the corners one at a time.
    public func radiusY(_ value: Double) -> Modified { setValue(.radiusY, .number(value)) }
}
