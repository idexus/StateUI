// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `ColorBox`'s own properties, shared by the control and its
/// `Style<ColorBox>`.
public protocol ColorBoxProperties: PropertyContainer {}

extension ColorBoxProperties {
    /// What the rectangle is filled with. Use this rather than `.background`,
    /// a second surface behind the box that its corner radius does not round.
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

extension ColorBox {
    /// `color` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    /// Not `.background`, which is a second square behind the one a box draws.
    public func color(_ state: Binding<Color>) -> Modified {
        journey(.color, by: state)
    }

    /// `cornerRadius` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func cornerRadius(_ state: Binding<Double>) -> Modified {
        plain(ColorBoxContract.cornerRadius.token, by: state)
    }
}
