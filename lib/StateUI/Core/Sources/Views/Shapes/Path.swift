// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Whatever an outline can be, written in SVG path syntax.
///
///     Path("M 0,40 L 20,0 L 40,40 Z")
///         .fill(.gold)
///         .contentMode(.fit)
///
/// `M` moves, `L` draws a line, `C` a curve, `A` an arc and `Z` closes the
/// figure. The numbers are device units in the path's OWN space, and `.contentMode`
/// says what happens to that space in the room the layout gives it - a path
/// drawn 40 wide fills a 200-wide cell under `.fit` and stays 40 under
/// `.center`.
///
/// Every platform accepts the same grammar: the host parses the path itself
/// before drawing it.
public struct Path: FilledShape, CorneredShape {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: PathContract.self)
    }

    /// The outline, in SVG path syntax.
    public init(_ data: String) {
        node = Node(contract: PathContract.self)
        node.write(PathContract.data, data)
    }

    /// Its outline, as SVG path data.
    func data(_ value: String) -> Modified { setValue(PathContract.data, value) }
}
