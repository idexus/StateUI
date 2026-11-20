// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a layout's arithmetic is handed to place its views: the room, and the views to measure.
///
///     placements: { context, turn in
///         context.subviews.indices.map { index in
///             Placement(Rect(x: Double(index) * 90 - turn * 90, y: 0, width: 80, height: context.bounds.height))
///         }
///     }
/// Design: docs/design/views/motion-layout.md#measuring-a-view
public struct LayoutContext<ID: Hashable> {
    /// The room the layout stands in, from its own top left, at its size.
    public let bounds: Rect

    /// The layout's views, in the items' order.
    public let subviews: LayoutSubviews<ID>
}

/// What a layout's `measure` is handed to say its own size: the room offered, and the views to measure.
/// Design: docs/design/views/motion-layout.md#a-size-of-its-own
public struct LayoutMeasurementContext<ID: Hashable> {
    /// The room the layout is offered.
    public let proposal: LayoutProposal

    /// The layout's views, in the items' order.
    public let subviews: LayoutSubviews<ID>
}
