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
            orderChildren()
            guard !takingRun else { return }

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

    /// The run a motion layout's program stands its children by in a room, asked in the pass that lays out a child
    /// it has shown no place for (`MountedElement.placementInRoom`).
    /// Design: docs/design/host/layout.md#placed-from-the-first-pass
    var placementInRoom: (@MainActor (LayoutSize) -> HostPlacementRun?)?
    private var takingRun = false

    /// The room inside the ZStack's own edge, in points.
    var padding = Insets(0) {
        didSet { if padding != oldValue { invalidateMeasurements() } }
    }

    /// Whether the ZStack stands a motion layout, whose children's sizes are no size of its own.
    var motionLayout = false

    /// The size a motion layout's program says for it in a width offered; nil where it says none.
    var programSize: (@MainActor (Double?) -> LayoutSize?)?

    /// Told the toolkit laid the layout out: where a view in it was sized anew, a motion layout's program measures
    /// its views again.
    /// Design: docs/design/host/layout.md#a-view-its-toolkit-sized-anew
    var onLaidOut: (@MainActor () -> Void)?

    override func contentSize(width: Double?) -> LayoutSize {
        ZStackArithmetic.size(of: items, padding: padding, width: width, motionLayout: motionLayout, program: programSize)
    }

    override func arrange(in bounds: Rect) {
        defer { onLaidOut?() }
        if let asked = placementInRoom?(LayoutSize(width: bounds.width, height: bounds.height)), asked != placement {
            takingRun = true
            placement = asked
            takingRun = false
        }
        if let run = placement, !run.placements.isEmpty {
            runRoom = bounds
            return apply(run, in: bounds)
        }

        beginArrangement(width: bounds.width, height: bounds.height)
        for item in items { item.view.setPlacedDrawing(nil, opacity: 1) }
        let room = Rect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        let places = ZStackArithmetic.places(of: items, in: room, padding: padding, direction: direction)
        for (item, place) in zip(items, places) {
            if let place { self.place(item, at: place) }
        }
    }

    /// A ZStack draws its children as its run ranks them, else in the tree's order, a child a shared entry
    /// carries last.
    override func orderChildren() {
        holdInDrawingOrder(placedBy: placement?.placements ?? [])
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
