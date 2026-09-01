// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: AbsoluteLayout.

/// Puts each child exactly where it is told, and nowhere else.
///
///     AbsoluteLayout {
///         BoxView(.cornflowerBlue)
///             .absoluteLayoutBounds(Rect(0, 0, 1, 1))
///             .absoluteLayoutFlags(.all)
///
///         Label("Bottom right")
///             .absoluteLayoutBounds(Rect(1, 1, AbsoluteLayout.autoSize, AbsoluteLayout.autoSize))
///             .absoluteLayoutFlags(.positionProportional)
///     }
///     .heightRequest(160)
///
/// Where a child sits is written on the CHILD, as in XAML -
/// `AbsoluteLayout.LayoutBounds="0,0,1,1"` is `.absoluteLayoutBounds(…)`. Those
/// two modifiers are on `ViewProperties`, so any view can carry them; see
/// Elements.swift.
///
/// The FLAGS decide how the four numbers in the bounds are read: each is either
/// a fraction of the layout or a length in device units. That is what makes an
/// absolute layout worth using on a screen whose size is not known -
/// `Rect(0.5, 0, 0.5, 1)` with `.all` is the right-hand half, whatever the
/// window turns out to be.
///
/// A child that says neither sits at 0,0 at the size it measures itself at,
/// which is MAUI's default - and is why children with no bounds of their own
/// end up drawn on top of one another.
public struct AbsoluteLayout: Layout {
    /// The node this control describes.
    public var node: Node

    /// Written in place of a width or a height in the bounds, to say that the
    /// child measures itself there rather than being given a size.
    /// MAUI: AbsoluteLayout.AutoSize, which is -1 there too.
    ///
    ///     Label("Bottom right")
    ///         .absoluteLayoutBounds(
    ///             Rect(1, 1, AbsoluteLayout.autoSize, AbsoluteLayout.autoSize))
    ///         .absoluteLayoutFlags(.positionProportional)
    ///
    /// Only the POSITION is proportional there: a size the child chooses is not
    /// a fraction of anything, so `.sizeProportional` and this cannot both be
    /// meant at once.
    public static let autoSize = -1.0

    /// An empty one - what a `Style<AbsoluteLayout>` is written against.
    public init() {
        node = Node(type: .absoluteLayout)
    }

    /// A layout holding what the closure describes. Where each child sits is
    /// written on the child, with `.absoluteLayoutBounds`.
    public init(@ViewBuilder content: () -> [Element]) {
        node = Node(type: .absoluteLayout, children: content().map { $0.body })
    }

    /// Says these children are ROWS: interchangeable subtrees, a few described
    /// at a time out of many, so the host keeps the control of a row that
    /// scrolls away and gives it to the next row of the same SHAPE.
    ///
    /// Internal, and it stays internal: what it promises is that any child of
    /// this layout could stand where any other of the same shape stands, which
    /// is true of a list's rows and of a gallery's cards by construction and
    /// is not something a caller can be asked to be sure of. See
    /// Core/Recycling.swift.
    func recycling() -> AbsoluteLayout {
        var copy = self
        copy.node.recycles = true
        return copy
    }
}
