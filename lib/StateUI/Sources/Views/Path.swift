// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Whatever an outline can be, written in SVG path syntax.
///
///     Path("M 0,40 L 20,0 L 40,40 Z")
///         .fill(.gold)
///         .aspect(.uniform)
///
/// `M` moves, `L` draws a line, `C` a curve, `A` an arc and `Z` closes the
/// figure. The numbers are device units in the path's OWN space, and `.aspect`
/// says what happens to that space in the room the layout gives it - a path
/// drawn 40 wide fills a 200-wide cell under `.uniform` and stays 40 under
/// `.none`.
///
/// The data crosses as SVG text and the shared host parser normalizes it to
/// absolute move, line, curve, arc and close commands. Native backends then
/// translate that closed vocabulary to their drawing APIs, so the accepted
/// grammar is not defined by any one platform.
public struct Path: Shape, PathProperties {
    /// The node this control describes.
    public var node: Node

    /// A path with no outline yet - what a `Style<Path>` is written against.
    public init() {
        node = Node(type: .path)
    }

    /// The outline, in SVG path syntax - which is the value that gives a Path
    /// its purpose, so it goes in the initializer.
    public init(_ data: String) {
        node = Node(type: .path, props: [.data: .string(data)])
    }
}

/// Path's own properties - the half a `Style<Path>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol PathProperties: PropertyContainer {}

extension PathProperties {
    /// The outline, in SVG path syntax - `"M 0,40 L 20,0 L 40,40 Z"`.
    ///
    /// The same value the initializer takes; write it here to give a
    /// `Style<Path>` an outline, or to swap one on a path that already has
    /// modifiers on it.
    public func data(_ value: String) -> Modified { setValue(.data, .string(value)) }
}
