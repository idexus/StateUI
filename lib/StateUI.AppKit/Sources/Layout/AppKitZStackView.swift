// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// A ZStack: its children one over another, each in its area, or where an engine's placement run puts it.
@MainActor
final class AppKitZStackView: AppKitTravellingLayout, AppKitWidthConstrainedMeasuring,
    AppKitMeasurementCaching {
    let measurements = MeasurementCache()
    var placement: HostPlacementRun? {
        didSet { needsLayout = true }
    }

    /// The room inside the ZStack's own edge.
    var padding = NSEdgeInsets() {
        didSet { if !NSEdgeInsetsEqual(padding, oldValue) { invalidateMeasurements() } }
    }
    private var items: [AppKitLayoutItem] = []
    private var drawingOrder: [ObjectIdentifier] = []

    override var isFlipped: Bool { true }

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

    /// The room its neediest child needs at its natural size, whatever width
    /// it is offered: measured once and kept until something under it
    /// changes.
    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        measurements.size(offering: nil) { measuredContentSize() }
    }

    private func measuredContentSize() -> NSSize {
        NSSize(ZStackArithmetic.size(of: items, padding: Insets(padding), width: nil))
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
            of: items, in: bounds.placed, padding: Insets(padding), direction: direction)
        for (item, place) in zip(items, places) {
            if let place { self.place(item, at: NSRect(placed: place)) }
        }
    }

    private func apply(_ placements: [HostPlacement]) {
        let count = min(items.count, placements.count)
        let ordered = (0..<count).sorted {
            placements[$0].zIndex == placements[$1].zIndex
                ? $0 < $1
                : placements[$0].zIndex < placements[$1].zIndex
        }
        let identities = ordered.map { ObjectIdentifier(items[$0].view) }

        if identities != drawingOrder {
            for index in ordered {
                let child = items[index].view
                child.removeFromSuperview()
                addSubview(child)
            }
            drawingOrder = identities
        }

        for index in 0..<count {
            let placement = placements[index]
            let item = items[index]
            item.view.frame = NSRect(
                x: placement.bounds.x,
                y: placement.bounds.y,
                width: max(0, placement.bounds.width),
                height: max(0, placement.bounds.height))
            (item.view as? AppKitGridView)?.setShadeOpacity(placement.shade)
            item.drawing?.placement = placement.drawing
            item.drawing?.placedOpacity = min(max(placement.opacity, 0), 1)
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
