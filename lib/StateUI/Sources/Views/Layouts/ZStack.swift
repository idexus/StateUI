// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Lays its children one over another, each in the whole room or in the area it names.
///
///     ZStack {
///         ColorBox(.cornflowerBlue)
///
///         Label("Bottom right")
///             .horizontalAlignment(.end)
///             .verticalAlignment(.end)
///
///         Label("Right half")
///             .area(.proportional(0.5, 0, 0.5, 1))
///     }
///     .height(160)
///
/// A child stands in its area by its own `horizontalAlignment` and
/// `verticalAlignment`, as in any layout, and fills it unless it says
/// otherwise. A later child is drawn over an earlier one; `zIndex` reorders
/// them without moving anything.
public struct ZStack: Layout {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ZStack>` is written against.
    public init() {
        node = Node(contract: ZStackContract.self)
    }

    /// A stack of the layers the closure describes, the first at the back.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(contract: ZStackContract.self)
        node.producer = { content().map { $0.body } }
    }
}
