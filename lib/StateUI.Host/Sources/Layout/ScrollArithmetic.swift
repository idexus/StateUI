// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A scroller's arithmetic: its content's size, and the document the content stands in.
/// Design: docs/design/host/layout.md#scrolling
@_spi(Host) public enum ScrollArithmetic {
    /// The content's natural size for the width offered; a scroller along its width offers none.
    @MainActor
    public static func contentSize<Child: LayoutChild>(
        of item: Child?, padding: Insets, orientation: ScrollOrientation, width offered: Double?
    ) -> LayoutSize {
        guard let item else { return .zero }

        let values = item.values
        let (across, down) = insets(values.margin, padding)
        let constrained = fitsWidth(orientation) ? offered.map { max(0, $0 - across) } : nil
        let natural = item.size(offered: constrained)
        let width = values.horizontal == 3 && values.width == nil ? (constrained ?? natural.width) : natural.width

        return LayoutSize(width: max(0, width + across), height: max(0, natural.height + down))
    }

    /// The document's size in `viewport`, never smaller than it, and where the child stands in it.
    @MainActor
    public static func arrange<Child: LayoutChild>(
        _ item: Child, padding: Insets, orientation: ScrollOrientation, in viewport: LayoutSize
    ) -> (document: LayoutSize, place: Rect) {
        let values = item.values
        let margin = values.margin
        let (across, down) = insets(margin, padding)
        let natural = item.size(offered: fitsWidth(orientation) ? max(0, viewport.width - across) : nil)
        let document = LayoutSize(
            width: orientation == .horizontal || orientation == .both
                ? max(viewport.width, natural.width + across) : viewport.width,
            height: orientation == .vertical || orientation == .both
                ? max(viewport.height, natural.height + down) : viewport.height)
        let room = Rect(
            x: padding.left + margin.left,
            y: padding.top + margin.top,
            width: max(0, document.width - across),
            height: max(0, document.height - down))
        let width = Extent.of(
            option: values.horizontal, stated: values.width, natural: natural.width,
            available: room.width, minimum: values.minimumWidth, maximum: values.maximumWidth)
        let height = Extent.of(
            option: values.vertical, stated: values.height, natural: natural.height,
            available: room.height, minimum: values.minimumHeight, maximum: values.maximumHeight)

        return (document, Rect(
            x: Extent.start(option: values.horizontal, extent: width, start: room.x, available: room.width),
            y: Extent.start(option: values.vertical, extent: height, start: room.y, available: room.height),
            width: max(0, width),
            height: max(0, height)))
    }

    /// Whether the content is held to the scroller's width: it scrolls only down, or not at all.
    private static func fitsWidth(_ orientation: ScrollOrientation) -> Bool {
        orientation == .vertical || orientation == .neither
    }

    /// The room the padding and the child's margin take, across and down.
    private static func insets(_ margin: Insets, _ padding: Insets) -> (across: Double, down: Double) {
        (padding.left + padding.right + margin.left + margin.right,
         padding.top + padding.bottom + margin.top + margin.bottom)
    }
}
