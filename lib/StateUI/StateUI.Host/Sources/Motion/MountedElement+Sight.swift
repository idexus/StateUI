// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The room a view goes out of - by `.outside(_:)`, or thrown away - is what shows it.
/// Design: docs/design/host/motion.md#out-of-sight
extension MountedElement {
    /// The element's place and room in what shows its layout; its layout's where that cuts what it holds or the
    /// toolkit says no rectangle. Nil where no layout placed it.
    func placeInWhatShowsIt() -> (place: Rect, room: LayoutSize)? {
        guard let placed = tree?.layoutMotion.placed(mount), let room = placed.room else { return nil }
        guard let sight = layoutParent?.standingInWhatShowsIt() else { return (placed.place, room) }

        let place = placed.place
        return (Rect(x: place.x + sight.corner.x, y: place.y + sight.corner.y, width: place.width, height: place.height),
                sight.room)
    }

    /// This element's corner in the nearest view above that cuts what it holds, and that view's size; nil where
    /// this one cuts what it holds itself or the toolkit says no rectangle.
    func standingInWhatShowsIt() -> (corner: Point, room: LayoutSize)? {
        guard !cutsWhatItHolds, let inner = native.frameNumbers(), inner.count >= 8 else { return nil }

        var above = parent
        while let view = above {
            if view.cutsWhatItHolds, let outer = view.native.frameNumbers(), outer.count >= 8 {
                return (Point(x: inner[4] - outer[4], y: inner[5] - outer[5]), LayoutSize(width: outer[2], height: outer[3]))
            }
            above = view.parent
        }
        return nil
    }

    /// Whether the element draws nothing it holds beyond its rectangle: a clipping layout, a scroller, a page.
    private var cutsWhatItHolds: Bool {
        type == .scrollView || type == .page || value(LayoutContract.clipsContent.token)?.bool == true
    }
}
