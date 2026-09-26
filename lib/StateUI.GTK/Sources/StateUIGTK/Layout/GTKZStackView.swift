// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ZStack: its children one over another, each in its area, or where an engine's placement run puts it.
/// Design: docs/design/platforms/gtk/drawing.md#a-placed-child
@MainActor
final class GTKZStackView: GTKTravellingLayout {
    /// The placement a state drives, one per child; nil while each child stands in its own area.
    var placement: HostPlacementRun? {
        didSet {
            guard placement != oldValue else { return }
            setChildren(heldViews())

            // A run moving on asks only for an allocation: its places need no room, so nothing around is measured.
            if let placements = placement?.placements, !placements.isEmpty, oldValue?.placements.isEmpty == false {
                apply(placements)
            } else {
                invalidateMeasurements()
            }
        }
    }

    /// The room inside the ZStack's own edge.
    var padding = Insets(0) {
        didSet { if padding != oldValue { invalidateMeasurements() } }
    }

    /// The children back to front as the run ranks them, or in their order without one: GTK draws a panel's
    /// children in that order and a click reaches the last first.
    override func heldViews() -> [GTKView] {
        ZStackArithmetic.drawingOrder(of: items.count, placedBy: placement?.placements ?? []).map { items[$0].view }
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

    /// Stands each child where the run says, drawn as it says: at once inside an allocation, and between them in
    /// the allocation each place asks for.
    private func apply(_ placements: [HostPlacement]) {
        let count = min(items.count, placements.count)
        for index in 0..<count {
            let placement = placements[index]
            let view = items[index].view
            view.setPlacedDrawing(placement.drawing, opacity: placement.drawnOpacity)
            view.layout(placement.place)
            (view as? GTKGridView)?.setShadeOpacity(placement.shade)
        }
        for item in items[count...] { item.view.setPlacedDrawing(nil, opacity: 1) }
    }
}
