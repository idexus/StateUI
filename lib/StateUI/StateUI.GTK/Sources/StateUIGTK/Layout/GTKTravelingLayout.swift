// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A layout whose children travel to their places by the host layer's rule (`TravelingPlaces`).
/// Design: docs/design/host/motion.md#layout-motion
@MainActor
class GTKTravelingLayout: GTKLayoutView {
    /// Where the children travel to their places.
    let places = TravelingPlaces()

    func beginArrangement(width: Double, height: Double) {
        places.begin(width: width, height: height)
    }

    /// Stands `item` at `place`, or on its way there.
    func place(_ item: GTKLayoutItem, at place: Rect) {
        places.place(
            item.view, mount: item.mount, at: place, values: item.values, natural: { item.size(offered: nil) },
            enter: item.enter)
    }

    /// The placements a run ranks the children by; none where the layout runs none.
    var rankedBy: [HostPlacement] { [] }

    /// The children and the views kept as they leave back to front as the layout draws them - in the tree's order, a
    /// run's ranks where `rankedBy` says them, each kept view after the one it stood after, a child a shared
    /// transition carries last: GTK draws a panel's children in that order and a click reaches the last first.
    /// Design: docs/design/host/layout.md#drawing-order
    override func heldViews() -> [GTKView] {
        let mounts = leaving.isEmpty ? items.map(\.mount) : presented
        var views: [UInt64: GTKView] = [:]
        for item in items { views[item.mount] = item.view }
        for (index, mount) in keptMounts.enumerated() where index < leaving.count { views[mount] = leaving[index] }
        let ordered = places.drawingOrder(of: mounts, kept: Set(keptMounts), placedBy: rankedBy).compactMap { views[mounts[$0]] }
        return ordered + (items.map(\.view) + leaving).filter { view in !ordered.contains { $0 === view } }
    }

    /// Draws the children again as the layout draws them.
    func orderChildren() {
        holdChildren()
    }
}
