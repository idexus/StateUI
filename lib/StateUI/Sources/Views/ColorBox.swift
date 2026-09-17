// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A host-native rectangle primitive.

/// A box's own properties - the half a `Style<ColorBox>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol ColorBoxProperties: PropertyContainer {}

extension ColorBoxProperties {
    /// What the rectangle is filled with.
    ///
    /// Not `.background`: a ColorBox carries both, and this is the one it
    /// draws - the background is a second surface behind it, which the corner
    /// radius does not round and which need not share the box's transform.
    /// A rotated box that carries both shows the background standing still
    /// underneath, so give a box its colour here and leave its background
    /// alone - in a style as much as on the control.
    public func color(_ value: Color) -> Modified {
        setValue(ColorBoxContract.color, value)
    }

    /// How rounded the corners are, in device units - the same radius on all
    /// four.
    ///
    /// A radius of half the side turns a square box into a circle.
    public func cornerRadius(_ value: Double) -> Modified {
        setValue(ColorBoxContract.cornerRadius, .uniform(value))
    }

    /// One corner at a time, in StateUI's declared order.
    ///
    ///     ColorBox().cornerRadius(topLeft: 16, topRight: 16, bottomLeft: 0, bottomRight: 0)
    ///
    /// - Parameters:
    ///   - topLeft: the top left corner.
    ///   - topRight: the top right corner.
    ///   - bottomLeft: the bottom left corner.
    ///   - bottomRight: the bottom right corner.
    public func cornerRadius(
        topLeft: Double,
        topRight: Double,
        bottomLeft: Double,
        bottomRight: Double
    ) -> Modified {
        setValue(
            ColorBoxContract.cornerRadius,
            .corners(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight))
    }
}

/// A host-native rectangle of colour.
///
///     ColorBox()
///         .color(.cornflowerBlue)
///         .cornerRadius(8)
///         .height(40)
///
/// The simplest thing a host draws: a divider, a bar of a chart, a placeholder,
/// or a deliberate piece of empty space. It has no content and no children -
/// for a coloured area around something, use a `Border`.
public struct ColorBox: View, ColorBoxProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ColorBox>` is written against.
    public init() {
        node = Node(contract: ColorBoxContract.self)
    }

    /// A rectangle drawn in `color`. Sized by `.width` and
    /// `.height`, or by the room the layout gives it.
    public init(_ color: Color) {
        node = Node(contract: ColorBoxContract.self)
        node.write(ColorBoxContract.color, color)
    }

}
