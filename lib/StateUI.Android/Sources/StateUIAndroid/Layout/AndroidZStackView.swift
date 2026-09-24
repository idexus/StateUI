// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A ZStack: its children one over another, each in its area, or where an engine's placement run puts it.
/// Design: docs/design/platforms/android/drawing.md#a-placed-child
@MainActor
final class AndroidZStackView: AndroidTravellingLayout {
    /// The placement a state drives, one per child; nil while each child stands in its own area.
    var placement: HostPlacementRun? {
        didSet {
            guard placement != oldValue else { return }
            holdInDrawingOrder()

            // A run moving on stands its children at once: its places need no room, so nothing around is laid out.
            if let placements = placement?.placements, !placements.isEmpty, oldValue?.placements.isEmpty == false {
                apply(placements)
            } else {
                requestLayout()
            }
        }
    }

    /// The room inside the ZStack's own edge, in points.
    var padding = Insets(0) {
        didSet { if padding != oldValue { invalidateMeasurements() } }
    }

    @discardableResult
    override func setItems(_ items: [AndroidLayoutItem]) -> Bool {
        defer { holdInDrawingOrder() }
        return super.setItems(items)
    }

    override func contentSize(width: Double?) -> LayoutSize {
        ZStackArithmetic.size(of: items, padding: padding, width: width)
    }

    override func arrange(in bounds: Rect) {
        if let placements = placement?.placements, !placements.isEmpty {
            return apply(placements)
        }

        beginArrangement(width: bounds.width)
        for item in items { item.view.setPlacedDrawing(nil, opacity: 1) }
        let room = Rect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        let places = ZStackArithmetic.places(of: items, in: room, padding: padding, direction: direction)
        for (item, place) in zip(items, places) {
            if let place { self.place(item, at: place) }
        }
    }

    /// Draws the children back to front as the run ranks them, or in their order without one: the order a touch
    /// reaches them in too, with nothing moved and nothing laid out again.
    private func holdInDrawingOrder() {
        let placements = placement?.placements ?? []
        let count = min(items.count, placements.count)
        let ordered = (0..<count).sorted {
            placements[$0].zIndex == placements[$1].zIndex
                ? $0 < $1
                : placements[$0].zIndex < placements[$1].zIndex
        } + Array(count..<items.count)
        setDrawingOrder(ordered == Array(items.indices) ? nil : ordered)
    }

    /// Stands each child where the run says, drawn as it says.
    private func apply(_ placements: [HostPlacement]) {
        let count = min(items.count, placements.count)
        for index in 0..<count {
            let placement = placements[index]
            let view = items[index].view
            view.layout(Rect(
                x: placement.bounds.x, y: placement.bounds.y,
                width: max(0, placement.bounds.width), height: max(0, placement.bounds.height)))
            view.setPlacedDrawing(placement.drawing, opacity: min(max(placement.opacity, 0), 1))
            (view as? AndroidGridView)?.setShadeOpacity(placement.shade)
        }
        for item in items[count...] { item.view.setPlacedDrawing(nil, opacity: 1) }
    }
}
