// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An oval filling the room it is given - a circle when that room is square.
///
///     Ellipse(.tomato)
///         .width(48)
///         .height(48)
///
/// An outline needs a `.stroke`, 1 unit wide unless `.lineWidth` says
/// otherwise.
///
/// A round avatar or a status dot is this control sized square. For a rounded
/// RECTANGLE, use a `Rectangle` with a `cornerRadius`, a `Capsule`, or a
/// layout with a `.shape`.
public struct Ellipse: FilledShape {
    /// The node this control describes.
    public var node: Node

    /// An ellipse - which is also what a `Style<Ellipse>` is written against.
    public init() {
        node = Node(contract: EllipseContract.self)
    }

    /// An ellipse painted with `fill`, a colour.
    public init(_ fill: Color) {
        self.init()
        self = self.fill(fill)
    }

    /// An ellipse painted with `fill`, a brush - a colour or a gradient.
    public init(_ fill: Brush) {
        self.init()
        self = self.fill(fill)
    }

    /// An ellipse painted with a colour state, `$x`: the host animates the colour to each new value, and no view is
    /// rebuilt for it.
    public init(_ fill: Binding<Color>) {
        self.init()
        self = self.fill(fill)
    }
}
