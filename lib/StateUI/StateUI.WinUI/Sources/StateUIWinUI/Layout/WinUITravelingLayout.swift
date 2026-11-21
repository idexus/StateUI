// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A layout whose children travel to their places by the host layer's rule (`TravelingPlaces`).
/// Design: docs/design/host/motion.md#layout-motion
@MainActor
class WinUITravelingLayout: WinUILayoutView {
    /// Where the children travel to their places.
    let places = TravelingPlaces()

    func beginArrangement(width: Double, height: Double) {
        places.begin(width: width, height: height)
    }

    /// Stands `item` at `place`, or on its way there.
    func place(_ item: WinUILayoutItem, at place: Rect) {
        places.place(
            item.view, mount: item.mount, at: place, values: item.values, natural: { item.size(offered: nil) },
            enter: item.enter)
    }

    @discardableResult
    override func setItems(_ items: [WinUILayoutItem]) -> Bool {
        defer { orderChildren() }
        return super.setItems(items)
    }

    /// Draws the children again as the layout draws them: in the tree's order, a child a shared entry carries last.
    func orderChildren() {
        holdInDrawingOrder(placedBy: [])
    }

    /// Draws the children back to front as the layout draws them - a run's ranks where `placements` say them, each
    /// view kept as it leaves after the one it stood after, a child a shared transition carries last - by each one's
    /// z-index: the order a click reaches them in too, with nothing moved and nothing laid out again.
    /// Design: docs/design/host/layout.md#drawing-order
    func holdInDrawingOrder(placedBy placements: [HostPlacement]) {
        let mounts = leaving.isEmpty ? items.map(\.mount) : presented
        var views: [UInt64: WinUIView] = [:]
        for item in items { views[item.mount] = item.view }
        for (index, mount) in keptMounts.enumerated() where index < leaving.count { views[mount] = leaving[index] }
        let ordered = places.drawingOrder(of: mounts, kept: Set(keptMounts), placedBy: placements)
            .compactMap { views[mounts[$0]] }
        let held = items.map(\.view) + leaving
        let inOrder = ordered.count == held.count && zip(ordered, held).allSatisfy { $0 === $1 }
        for (rank, view) in ordered.enumerated() {
            view.setZIndex(inOrder ? 0 : Int32(rank))
        }
    }
}
