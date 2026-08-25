// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: Path.

/// Whatever an outline can be, written in SVG's path syntax. MAUI: Path.
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
/// The data crosses as the very string XAML writes, and the host hands it to
/// MAUI's own `PathGeometryConverter` - the one MAUI converter this library
/// calls. The grammar is open-ended, where every other structured value - a
/// stroke shape, a row definition list, a brush - has a fixed shape and crosses
/// as typed parts. Nothing here reads the string, so a mistyped path is MAUI's
/// converter to complain about at render time rather than the compiler's.
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
    /// MAUI: Path.Data, which is a Geometry.
    ///
    /// The same value the initializer takes; write it here to give a
    /// `Style<Path>` an outline, or to swap one on a path that already has
    /// modifiers on it.
    public func data(_ value: String) -> Modified { setValue(.data, .string(value)) }

    /// A transform applied to the geometry before it is drawn.
    /// MAUI: Path.RenderTransform.
    ///
    ///     Path("M 0 0 L 40 0 L 40 40 Z")
    ///         .renderTransform(.group([.rotate(15), .scale(x: 1.2, y: 1)]))
    ///
    /// Not the same as `.rotation` and `.scale`, which every view has: those
    /// turn and resize the VIEW after the layout has placed it, while this
    /// changes the geometry itself - so the stroke follows it, and a skew is
    /// possible at all.
    public func renderTransform(_ value: Transform) -> Modified {
        setValue(.renderTransform, value.propValue)
    }
}
