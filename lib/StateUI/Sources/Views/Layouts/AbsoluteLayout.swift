// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Puts each child exactly where it is told, and nowhere else.
///
///     AbsoluteLayout {
///         ColorBox(.cornflowerBlue)
///             .absoluteLayoutBounds(Rect(0, 0, 1, 1))
///             .absoluteLayoutProportions(.all)
///
///         Label("Bottom right")
///             .absoluteLayoutBounds(Rect(1, 1, AbsoluteLayout.autoSize, AbsoluteLayout.autoSize))
///             .absoluteLayoutProportions(.position)
///     }
///     .height(160)
///
/// Where a child sits is written on the child, with `.absoluteLayoutBounds(…)`
/// and `.absoluteLayoutProportions(…)`. The proportions say which of the four
/// numbers are fractions of the layout rather than device units:
/// `Rect(0.5, 0, 0.5, 1)` with `.all` is the right-hand half, whatever the
/// window's size.
///
/// A child that says neither sits at 0,0 at the size it measures itself at -
/// which is why children with no bounds of their own end up drawn on top of
/// one another.
public struct AbsoluteLayout: Layout {
    /// The node this control describes.
    public var node: Node

    /// Written in place of a width or a height in the bounds, to say that the
    /// child measures itself there rather than being given a size.
    ///
    ///     Label("Bottom right")
    ///         .absoluteLayoutBounds(
    ///             Rect(1, 1, AbsoluteLayout.autoSize, AbsoluteLayout.autoSize))
    ///         .absoluteLayoutProportions(.position)
    ///
    /// Only the position can be proportional there: a size the child chooses
    /// is not a fraction of anything.
    public static let autoSize = -1.0

    /// An empty one - what a `Style<AbsoluteLayout>` is written against.
    public init() {
        node = Node(contract: AbsoluteLayoutContract.self)
    }

    /// A layout holding what the closure describes. Where each child sits is
    /// written on the child, with `.absoluteLayoutBounds`.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(contract: AbsoluteLayoutContract.self)
        node.producer = { content().map { $0.body } }
    }

    /// Says these children are rows the host may keep and hand to the next row
    /// of the same shape - internal, since only this library can promise it.
    /// Design: docs/design/core/identity-and-diffing.md#recycling
    func recycling() -> AbsoluteLayout {
        var copy = self
        copy.node.recycles = true
        return copy
    }
}
