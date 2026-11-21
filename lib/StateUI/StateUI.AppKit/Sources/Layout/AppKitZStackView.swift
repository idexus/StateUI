// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ZStack: its children one over another, each in its area, or where a motion layout's placements put it.
@MainActor
final class AppKitZStackView: AppKitTravelingLayout, AppKitWidthConstrainedMeasuring,
    AppKitMeasurementCaching {
    let measurements = MeasurementCache()
    var placement: HostPlacementRun? {
        didSet { needsLayout = true }
    }

    /// The room inside the ZStack's own edge.
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

    private var items: [AppKitLayoutItem] = []

    override var isFlipped: Bool { true }

    func setItems(_ items: [AppKitLayoutItem]) {
        setItems(items, presenting: items.map(\.view))
    }

    /// Takes `items` to measure and place, and `views` - theirs, and those of children kept as they leave - as its
    /// subviews in that order: a view no item names stands where it stood.
    /// Design: docs/design/platforms/appkit/views.md#a-view-kept-as-it-leaves
    func setItems(_ items: [AppKitLayoutItem], presenting views: [NSView]) {
        presented = views
        let same = AppKitLayoutItem.sameArrangement(self.items, items)
        if !same { self.items = items }
        orderChildren()
        if !same { invalidateMeasurements() }
    }

    /// A ZStack draws its children as its run ranks them, else in the tree's order, a child a shared entry carries
    /// last. Turned in place, a child taken out and put back leaves the window, and a gesture under way on it is
    /// cancelled: the order is stood again only where it moved. Design: docs/design/platforms/appkit/views.md#a-child-turned-in-place
    override func orderChildren() {
        standInDrawingOrder(of: items, placedBy: placement?.placements ?? [])
    }

    override var intrinsicContentSize: NSSize {
        fittingContentSize(width: nil)
    }

    /// The room its neediest child needs for the width offered - wrapped words as tall as that width makes
    /// them: measured once for each width and kept until something under it changes.
    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        measurements.size(offering: availableWidth) { measuredContentSize(width: availableWidth) }
    }

    private func measuredContentSize(width: CGFloat?) -> NSSize {
        NSSize(ZStackArithmetic.size(of: items, padding: padding, width: width.map(Double.init), motionLayout: motionLayout,
            program: programSize))
    }

    override func layout() {
        super.layout()
        defer { onLaidOut?() }

        if let run = placement, !run.placements.isEmpty {
            apply(run)
            return
        }

        beginArrangement()
        for item in items { drawUnplaced(item) }
        let places = ZStackArithmetic.places(
            of: items, in: arrangementBounds.placed, padding: padding, direction: direction)
        for (item, place) in zip(items, places) {
            if let place { self.place(item, at: NSRect(placed: place)) }
        }
    }

    private func apply(_ run: HostPlacementRun) {
        let placements = run.placements
        let count = min(items.count, placements.count)
        orderChildren()

        for index in 0..<count {
            let placement = placements[index]
            let item = items[index]
            item.view.frame = NSRect(placed: run.place(of: index, in: bounds.placed))
            (item.view as? AppKitGridView)?.setShadeOpacity(placement.drawnShade)
            item.drawing?.placement = run.drawing(of: index)
            item.drawing?.placedOpacity = placement.drawnOpacity
        }
        for item in items[count...] { drawUnplaced(item) }
    }

    /// A child the run places nothing for is drawn by its own values alone.
    private func drawUnplaced(_ item: AppKitLayoutItem) {
        item.drawing?.placement = nil
        item.drawing?.placedOpacity = 1
    }
}

#endif
