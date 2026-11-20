// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One view of a layout, as its arithmetic meets it: which item it shows, and how large it is in a room offered.
///
///     placements: { context, _ in
///         var across = 0.0
///         return context.subviews.map { view in
///             let size = view.sizeThatFits(height: context.bounds.height)
///             defer { across += size.width + 8 }
///             return Placement(Rect(x: across, y: 0, width: size.width, height: size.height))
///         }
///     }
///
/// It is a handle: it holds no view, and measuring writes nothing.
/// Design: docs/design/views/motion-layout.md#measuring-a-view
public struct LayoutSubview<ID: Hashable> {
    /// The identity of the item the view shows.
    public let id: ID

    /// The view's place among the layout's views.
    let index: Int

    /// What measures the view; nil where nothing does.
    let measuring: LayoutMeasuring?

    /// The size the view takes in a room `width` by `height`: its own size along a side left out, its words wrapped
    /// to a width offered. Its stated sizes and bounds are in the answer; its margin is not.
    ///
    /// Nought where nothing measures the view: before its layout stands in a window, and in a test's window with
    /// no toolkit.
    ///
    /// - Parameters:
    ///   - width: the width offered; none where left out. Below nought it is nought.
    ///   - height: the height offered; none where left out. Below nought it is nought.
    /// - Returns: the size the view takes.
    @MainActor
    public func sizeThatFits(width: Double? = nil, height: Double? = nil) -> LayoutSize {
        measuring?.measured(index, LayoutProposal(width: width, height: height)).size ?? .zero
    }

    /// How far below its top the view's first line of words rests in a room `width` by `height`; nil for a view
    /// with no words.
    ///
    /// - Parameters:
    ///   - width: the width offered; none where left out.
    ///   - height: the height offered; none where left out.
    /// - Returns: the baseline's distance from the view's top.
    @MainActor
    public func firstBaseline(width: Double? = nil, height: Double? = nil) -> Double? {
        measuring?.measured(index, LayoutProposal(width: width, height: height)).firstBaseline
    }
}

/// The views of a layout, in the items' order, found by their place or by their item's identity.
public struct LayoutSubviews<ID: Hashable>: RandomAccessCollection {
    /// A view's place among the layout's views.
    public typealias Index = Int

    /// One view of the layout.
    public typealias Element = LayoutSubview<ID>

    private let views: [LayoutSubview<ID>]
    private let places: [ID: Int]

    /// The views of the items identified by `ids`, in order, measured by `measuring`.
    init(_ ids: [ID], measuring: LayoutMeasuring?) {
        views = ids.enumerated().map { LayoutSubview(id: $1, index: $0, measuring: measuring) }
        places = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The first view's place: 0.
    public var startIndex: Int { views.startIndex }

    /// One past the last view's place.
    public var endIndex: Int { views.endIndex }

    /// The view at `index`.
    public subscript(_ index: Int) -> LayoutSubview<ID> { views[index] }

    /// The view of the item identified by `id`; nil where the layout shows no such item.
    public subscript(id id: ID) -> LayoutSubview<ID>? { places[id].map { views[$0] } }

    /// The place after `index`.
    public func index(after index: Int) -> Int { index + 1 }

    /// The place before `index`.
    public func index(before index: Int) -> Int { index - 1 }

    /// The place `distance` on from `index`.
    public func index(_ index: Int, offsetBy distance: Int) -> Int { index + distance }

    /// How many places lie from `start` to `end`.
    public func distance(from start: Int, to end: Int) -> Int { end - start }
}
