// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Whatever an outline can be, written in SVG path syntax.
///
///     Path("M 0,40 L 20,0 L 40,40 Z")
///         .fill(.gold)
///         .aspect(.fit)
///
/// `M` moves, `L` draws a line, `C` a curve, `A` an arc and `Z` closes the
/// figure. The numbers are device units in the path's OWN space, and `.aspect`
/// says what happens to that space in the room the layout gives it - a path
/// drawn 40 wide fills a 200-wide cell under `.fit` and stays 40 under
/// `.center`.
///
/// Every platform accepts the same grammar: the host parses the path itself
/// before drawing it.
public struct Path: Shape, PathProperties {
    /// The node this control describes.
    public var node: Node

    /// A path with no outline yet - what a `Style<Path>` is written against.
    public init() {
        node = Node(contract: PathContract.self)
    }

    /// The outline, in SVG path syntax.
    public init(_ data: String) {
        node = Node(contract: PathContract.self)
        node.write(PathContract.data, data)
    }
}

/// `Path`'s own properties, shared by the control and its `Style<Path>`.
public protocol PathProperties: PropertyContainer {}

extension PathProperties {
    /// The outline, in SVG path syntax - `"M 0,40 L 20,0 L 40,40 Z"`.
    ///
    /// The same value the initializer takes; write it here to give a
    /// `Style<Path>` an outline, or to swap one on a path that already has
    /// modifiers on it.
    public func data(_ value: String) -> Modified { setValue(PathContract.data, value) }
}
