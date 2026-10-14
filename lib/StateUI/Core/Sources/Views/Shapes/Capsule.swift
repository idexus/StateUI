// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A rectangle whose shorter sides round whole, filling the room it is given - a pill, a badge, a track.
///
///     Capsule(.teal)
///         .width(120)
///         .height(32)
///
/// Its ends stay round however wide or tall its room stands: the radius is always half the shorter side. In a
/// square room it is a circle. An outline needs a `.stroke`, 1 unit wide unless `.lineWidth` says otherwise.
public struct Capsule: FilledShape {
    /// The node this control describes.
    public var node: Node

    /// A capsule with nothing set - which is also what a `Style<Capsule>` is written against.
    public init() {
        node = Node(contract: CapsuleContract.self)
    }

    /// A capsule painted with `fill`, a colour.
    public init(_ fill: Color) {
        self.init()
        self = self.fill(fill)
    }

    /// A capsule painted with `fill`, a brush - a colour or a gradient.
    public init(_ fill: Brush) {
        self.init()
        self = self.fill(fill)
    }

    /// A capsule painted with a colour state, `$x`: the host animates the colour to each new value, and no view is
    /// rebuilt for it.
    public init(_ fill: Binding<Color>) {
        self.init()
        self = self.fill(fill)
    }
}
