// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A rectangle, drawn as a shape - with square corners, or rounded ones.
///
///     Rectangle()
///         .fill(.cornflowerBlue)
///         .cornerRadius(8)
///         .height(60)
///
/// A `ColorBox` says the same thing in one line and takes one colour; this is the
/// shape, so it takes a Brush, an outline and everything else the shape tier
/// declares.
///
/// It has no size of its own: give it a `height`, a `width` or a
/// layout that stretches it, or it draws nothing.
public struct Rectangle: Shape, RectangleProperties {
    /// The node this control describes.
    public var node: Node

    /// A rectangle with nothing set - which is also what a `Style<Rectangle>` is
    /// written against.
    public init() {
        node = Node(contract: RectangleContract.self)
    }
}

/// Rectangle's own properties - the half a `Style<Rectangle>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol RectangleProperties: PropertyContainer {}

extension RectangleProperties {
    /// The same radius on all four corners, in device units. 0 - the default -
    /// is a square corner.
    public func cornerRadius(_ value: Double) -> Modified {
        setValue(RectangleContract.cornerRadius, .uniform(value))
    }

    /// One corner at a time, each in device units.
    ///
    ///     Rectangle()
    ///         .cornerRadius(topLeft: 16, topRight: 16, bottomLeft: 0, bottomRight: 0)
    ///         .fill(.whiteSmoke)
    ///
    /// A card rounded along the top and flush along the bottom, which is what
    /// naming them separately is for. The labels are required, so there is no
    /// order to remember at the call site.
    public func cornerRadius(
        topLeft: Double,
        topRight: Double,
        bottomLeft: Double,
        bottomRight: Double
    ) -> Modified {
        setValue(
            RectangleContract.cornerRadius,
            .corners(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight))
    }
}
