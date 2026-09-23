// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// One parsed row or column definition in a StateUI grid.
/// AppKit's deterministic implementation of StateUI's row-and-column layout.
@MainActor
final class AppKitGridView: AppKitTravellingLayout, AppKitWidthConstrainedMeasuring,
    AppKitMeasurementCaching {
    let measurements = MeasurementCache()
    var rows: [GridLength] = [] {
        didSet { if rows != oldValue { invalidateMeasurements() } }
    }
    var columns: [GridLength] = [] {
        didSet { if columns != oldValue { invalidateMeasurements() } }
    }
    var rowSpacing: CGFloat = 0 {
        didSet { if rowSpacing != oldValue { invalidateMeasurements() } }
    }
    var columnSpacing: CGFloat = 0 {
        didSet { if columnSpacing != oldValue { invalidateMeasurements() } }
    }
    var padding = NSEdgeInsets() {
        didSet { if !NSEdgeInsetsEqual(padding, oldValue) { invalidateMeasurements() } }
    }
    private var items: [AppKitLayoutItem] = []

    override var isFlipped: Bool { true }

    func setItems(_ items: [AppKitLayoutItem]) {
        guard !AppKitLayoutItem.sameArrangement(self.items, items) else { return }

        replaceSubviews(with: items.map(\.view))
        self.items = items
        invalidateMeasurements()
    }

    /// Applies a placed layout's shade to its guaranteed second child.
    func setShadeOpacity(_ opacity: Double) {
        guard items.count > 1 else { return }
        items[1].view.alphaValue = min(max(opacity, 0), 1)
    }

    override var intrinsicContentSize: NSSize {
        fittingContentSize(width: nil)
    }

    /// The grid at its tracks' natural sizes, whatever width it is offered:
    /// measured once and kept until something under it changes.
    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        measurements.size(offering: nil) { measuredContentSize() }
    }

    private func measuredContentSize() -> NSSize {
        NSSize(GridArithmetic.size(
            of: items, rows: rows, columns: columns, rowSpacing: Double(rowSpacing),
            columnSpacing: Double(columnSpacing), padding: Insets(padding)))
    }

    override func layout() {
        super.layout()

        beginArrangement()
        let places = GridArithmetic.places(
            of: items, rows: rows, columns: columns, rowSpacing: Double(rowSpacing),
            columnSpacing: Double(columnSpacing), padding: Insets(padding), in: bounds.placed)
        for (item, place) in zip(items, places) {
            if let place { self.place(item, at: NSRect(placed: place)) }
        }
    }
}

#endif
