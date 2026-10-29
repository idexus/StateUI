// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A one-child native container used by pages and content-bearing controls.
@MainActor
class AppKitSingleChildView: AppKitHitTestView, AppKitWidthConstrainedMeasuring,
    AppKitMeasurementCaching, AppKitDirectedLayout {
    let measurements = MeasurementCache()
    var direction = LayoutDirection.leftToRight {
        didSet { if direction != oldValue { needsLayout = true } }
    }

    private(set) var item: AppKitLayoutItem?

    override var isFlipped: Bool { true }

    func setItem(_ item: AppKitLayoutItem?) {
        guard !AppKitLayoutItem.sameArrangement(self.item, item) else { return }

        replaceSubviews(with: item.map { [$0.view] } ?? [])
        self.item = item
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

    private func measuredContentSize(width availableWidth: CGFloat?) -> NSSize {
        NSSize(SingleChildArithmetic.size(of: item, width: availableWidth.map(Double.init)))
    }

    override func layout() {
        super.layout()
        guard let item, item.isShown else { return }

        item.view.frame = NSRect(placed: SingleChildArithmetic.place(of: item, in: childRoom, direction: direction))
    }

    /// The room the child stands in: the whole view.
    var childRoom: Rect { bounds.placed }
}

#endif
