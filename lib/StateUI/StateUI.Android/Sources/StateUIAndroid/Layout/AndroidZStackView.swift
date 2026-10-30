// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ZStack: its children one over another, each in its area, or where a motion layout's placements put it.
/// Design: docs/design/platforms/android/drawing.md#a-placed-child
@MainActor
final class AndroidZStackView: AndroidTravelingLayout {
    /// The placement a state drives, one per child; nil while each child stands in its own area.
    var placement: HostPlacementRun? {
        didSet {
            guard placement != oldValue else { return }
            holdInDrawingOrder()

            // A run moving on stands its children at once in the room it last stood them in: nothing around is laid out.
            if let run = placement, !run.placements.isEmpty, oldValue?.placements.isEmpty == false,
               let room = runRoom {
                apply(run, in: room)
            } else {
                requestLayout()
            }
        }
    }

    /// The room the run last stood its children in, where a run moving on stands them again.
    private var runRoom: Rect?

    /// The room inside the ZStack's own edge, in points.
    var padding = Insets(0) {
        didSet { if padding != oldValue { invalidateMeasurements() } }
    }

    /// Whether the ZStack stands a motion layout, which has no size of its own.
    var motionLayout = false

    @discardableResult
    override func setItems(_ items: [AndroidLayoutItem]) -> Bool {
        defer { holdInDrawingOrder() }
        return super.setItems(items)
    }

    override func contentSize(width: Double?) -> LayoutSize {
        ZStackArithmetic.size(of: items, padding: padding, width: width, motionLayout: motionLayout)
    }

    override func arrange(in bounds: Rect) {
        if let run = placement, !run.placements.isEmpty {
            runRoom = bounds
            return apply(run, in: bounds)
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
        let ordered = ZStackArithmetic.drawingOrder(of: items.count, placedBy: placement?.placements ?? [])
        setDrawingOrder(ordered == Array(items.indices) ? nil : ordered)
    }

    /// Stands each child where the run says, drawn as it says.
    private func apply(_ run: HostPlacementRun, in room: Rect) {
        let placements = run.placements
        let count = min(items.count, placements.count)
        for index in 0..<count {
            let placement = placements[index]
            let view = items[index].view
            view.layout(run.place(of: index, in: room))
            view.setPlacedDrawing(run.drawing(of: index), opacity: placement.drawnOpacity)
            (view as? AndroidGridView)?.setShadeOpacity(placement.drawnShade)
        }
        for item in items[count...] { item.view.setPlacedDrawing(nil, opacity: 1) }
    }
}
