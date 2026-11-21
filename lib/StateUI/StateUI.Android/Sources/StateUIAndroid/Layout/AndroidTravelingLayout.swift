// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A layout whose children animate to the places a patch gives them.
/// Design: docs/design/host/motion.md#layout-motion
@MainActor
class AndroidTravelingLayout: AndroidLayoutView {
    /// How the children travel to their places, by the host layer's rule.
    let places = TravelingPlaces()

    /// Starts an arrangement in a room `width` by `height` points, deciding once for every child how it is placed.
    func beginArrangement(width: Double, height: Double) {
        places.begin(width: width, height: height)
    }

    /// Stands `item` at `place`, or on its way there.
    func place(_ item: AndroidLayoutItem, at place: Rect) {
        places.place(
            item.view, mount: item.mount, at: place, values: item.values, natural: { item.size(offered: nil) },
            enter: item.enter)
    }

    @discardableResult
    override func setItems(_ items: [AndroidLayoutItem]) -> Bool {
        defer { orderChildren() }
        return super.setItems(items)
    }

    /// Draws the children again as the layout draws them: in the tree's order, a child a shared entry carries last.
    func orderChildren() {
        holdInDrawingOrder(placedBy: [])
    }

    /// Draws the children, and hands them touches, back to front as the layout draws them - a run's ranks where
    /// `placements` say them, a child a shared entry carries last - with nothing moved and nothing laid out again;
    /// the views kept as they leave stand after the items', and are drawn over them.
    /// Design: docs/design/host/layout.md#drawing-order
    func holdInDrawingOrder(placedBy placements: [HostPlacement]) {
        let ordered = places.drawingOrder(of: items.map(\.mount), placedBy: placements)
        setDrawingOrder(
            ordered == Array(items.indices) ? nil : ordered + Array(items.count..<(items.count + leaving.count)))
    }
}
