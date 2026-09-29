// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A deterministic frame-based stack shared by horizontal and vertical stacks.
@MainActor
final class AppKitStackView: AppKitTravellingLayout, AppKitWidthConstrainedMeasuring,
    AppKitMeasurementCaching {
    let axis: StackArithmetic.Axis
    let measurements = MeasurementCache()
    var spacing: CGFloat = 0 {
        didSet { if spacing != oldValue { invalidateMeasurements() } }
    }
    var padding = NSEdgeInsets() {
        didSet { if !NSEdgeInsetsEqual(padding, oldValue) { invalidateMeasurements() } }
    }
    private(set) var items: [AppKitLayoutItem] = []
    private(set) var arrangementCountForTesting = 0

    init(axis: StackArithmetic.Axis) {
        self.axis = axis
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitStackView is created in code")
    }

    override var isFlipped: Bool { true }

    func setItems(_ items: [AppKitLayoutItem]) {
        arrangementCountForTesting += 1
        guard !AppKitLayoutItem.sameArrangement(self.items, items) else { return }

        replaceSubviews(with: items.map(\.view))
        self.items = items
        invalidateMeasurements()
    }

    override var intrinsicContentSize: NSSize {
        fittingContentSize(width: nil)
    }

    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        measurements.size(offering: availableWidth) {
            measuredContentSize(width: availableWidth)
        }
    }

    /// Measures each visible child once for the width this stack offers it.
    private func measuredContentSize(width availableWidth: CGFloat?) -> NSSize {
        NSSize(StackArithmetic.size(
            of: items, axis: axis, spacing: Double(spacing), padding: Insets(padding),
            width: availableWidth.map(Double.init)))
    }

    override func layout() {
        super.layout()

        beginArrangement()
        let places = StackArithmetic.places(
            of: items, axis: axis, spacing: Double(spacing), padding: Insets(padding), in: bounds.placed,
            direction: direction)
        for (item, place) in zip(items, places) {
            if let place { self.place(item, at: NSRect(placed: place)) }
        }
    }
}

#endif
