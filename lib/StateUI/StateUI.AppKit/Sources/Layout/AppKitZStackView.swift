// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ZStack: its children one over another, each in its area, or where an engine's placement run puts it.
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

    /// Whether the ZStack stands a layout engine, which has no size of its own.
    var engine = false

    /// The hand over the layout engine it stands, where one moves it: whether it took a scroll event.
    var hand: ((NSEvent) -> Bool)?
    private var items: [AppKitLayoutItem] = []
    private var drawingOrder: [ObjectIdentifier] = []

    override var isFlipped: Bool { true }

    /// A scroll the layout's hand does not take goes on to whatever holds the layout.
    override func scrollWheel(with event: NSEvent) {
        if hand?(event) == true { return }

        super.scrollWheel(with: event)
    }

    func setItems(_ items: [AppKitLayoutItem]) {
        guard !AppKitLayoutItem.sameArrangement(self.items, items) else { return }

        replaceSubviews(with: items.map(\.view))
        self.items = items
        drawingOrder = []
        invalidateMeasurements()
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
        NSSize(ZStackArithmetic.size(of: items, padding: padding, width: width.map(Double.init), engine: engine))
    }

    override func layout() {
        super.layout()

        if let placements = placement?.placements, !placements.isEmpty {
            apply(placements)
            return
        }

        beginArrangement()
        for item in items { drawUnplaced(item) }
        let places = ZStackArithmetic.places(
            of: items, in: bounds.placed, padding: padding, direction: direction)
        for (item, place) in zip(items, places) {
            if let place { self.place(item, at: NSRect(placed: place)) }
        }
    }

    private func apply(_ placements: [HostPlacement]) {
        let count = min(items.count, placements.count)
        let ordered = ZStackArithmetic.drawingOrder(of: items.count, placedBy: placements)
        let identities = ordered.map { ObjectIdentifier(items[$0].view) }

        // Turned in place: a child taken out and put back leaves the window, and a gesture under way on it is
        // cancelled. Design: docs/design/platforms/appkit/views.md#a-child-turned-in-place
        if identities != drawingOrder {
            subviews = subviews.filter { $0 is any AppKitBoxSurface } + ordered.map { items[$0].view }
            drawingOrder = identities
        }

        for index in 0..<count {
            let placement = placements[index]
            let item = items[index]
            item.view.frame = NSRect(placed: placement.place)
            (item.view as? AppKitGridView)?.setShadeOpacity(placement.drawnShade)
            item.drawing?.placement = placement.drawing
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
