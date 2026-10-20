// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// AppKit's presentation of the stack whose identity stays in Swift.
///
/// Every page view remains owned by its `AppKitElement`; this view shows only
/// the top one, across its whole frame. The stack's furniture - the top
/// page's title, the way back and the page's actions - is the window's
/// toolbar, which the window controller composes from the visible
/// arrangement, so AppKit is given no second navigation model to reconcile
/// with StateUI's path.
@MainActor
final class AppKitNavigationView: AppKitHitTestView, AppKitWidthConstrainedMeasuring, AppKitDirectedLayout {
    private var items: [AppKitLayoutItem] = []

    /// The direction the stack lays its page out in, which says which side its margin's start is.
    var direction = LayoutDirection.leftToRight

    override var isFlipped: Bool { true }

    func setItems(_ items: [AppKitLayoutItem]) {
        guard !AppKitLayoutItem.sameArrangement(self.items, items) else { return }

        let previous = self.items.last?.view
        let next = items.last?.view
        self.items = items

        if previous !== next {
            previous?.removeFromSuperview()
            if let next { addSubview(next) }
        }

        invalidateMeasurements()
    }

    override var intrinsicContentSize: NSSize {
        fittingContentSize(width: nil)
    }

    /// The top page's size, measured by the page for the width offered.
    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        guard let item = items.last else { return .zero }
        let margin = item.values.margin.sides(in: direction)
        let size = item.fittingSize(width: availableWidth.map { max(0, $0 - margin.left - margin.right) })
        return NSSize(
            width: size.width + margin.left + margin.right,
            height: size.height + margin.top + margin.bottom)
    }

    override func layout() {
        super.layout()
        guard let item = items.last else { return }

        let margin = item.values.margin.sides(in: direction)
        item.view.frame = NSRect(
            x: margin.left,
            y: margin.top,
            width: max(0, bounds.width - margin.left - margin.right),
            height: max(0, bounds.height - margin.top - margin.bottom))
    }

    var topViewForTesting: NSView? { items.last?.view }
}

#endif
