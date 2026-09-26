// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One child as its AppKit layout places it: its view, and what the layout reads of it.
@MainActor
struct AppKitLayoutItem: LayoutChild {
    let view: NSView

    /// What the layout reads of the child.
    var values = LayoutValues()

    /// The mounted identity of the element the view presents; 0 for a view no element presents.
    var mount: UInt64 = 0

    /// The element that places the view as its layout animates it; nil for a view no element presents.
    weak var placed: (any PlacedView)?

    /// Fades the view in as it joins a standing layout; nil for a view that simply appears.
    var fadeIn: ((Motion) -> Void)?

    /// How the view is drawn over its frame, for a layout that places it.
    var drawing: AppKitViewDrawing?

    init(view: NSView, values: LayoutValues = LayoutValues()) {
        self.view = view
        self.values = values
    }

    /// A child stating its own size.
    init(view: NSView, width: CGFloat?, height: CGFloat?) {
        self.view = view
        values.width = width.map(Double.init)
        values.height = height.map(Double.init)
    }

    var isShown: Bool { !view.isHidden }

    /// The child's margin, in AppKit's units.
    var margin: NSEdgeInsets {
        let margin = values.margin
        return NSEdgeInsets(top: margin.top, left: margin.left, bottom: margin.bottom, right: margin.right)
    }

    func size(offered width: Double?) -> LayoutSize {
        LayoutSize(fittingSize(width: width.map { CGFloat($0) }))
    }

    /// The view's size for the width offered to it, its margin already taken out: measured at the width it takes of
    /// the offer, its stated sizes and bounds applied (`LayoutValues.offer`, `sized`).
    /// Design: docs/design/host/layout.md#a-child-measured
    func fittingSize(width available: CGFloat? = nil) -> NSSize {
        let offer = values.offer(available.map { Double($0) }).map { CGFloat($0) }
        let measured: NSSize
        if let measurable = view as? AppKitWidthConstrainedMeasuring {
            measured = measurable.fittingContentSize(width: offer)
        } else {
            if let label = view as? NSTextField, let offer, offer.isFinite {
                label.preferredMaxLayoutWidth = offer
            }
            measured = view.fittingSize
        }
        let sized = values.sized(LayoutSize(width: Double(measured.width), height: Double(measured.height)))
        return NSSize(width: sized.width, height: sized.height)
    }

    /// Whether a parent would place this item as it places `other`: the same view with the same values.
    func arranges(like other: AppKitLayoutItem) -> Bool {
        view === other.view && values == other.values
    }

    /// Whether two complete arrangements place the same views the same way.
    static func sameArrangement(_ left: [AppKitLayoutItem], _ right: [AppKitLayoutItem]) -> Bool {
        left.count == right.count && zip(left, right).allSatisfy { $0.arranges(like: $1) }
    }

    /// Whether two optional single-child arrangements are the same.
    static func sameArrangement(_ left: AppKitLayoutItem?, _ right: AppKitLayoutItem?) -> Bool {
        switch (left, right) {
        case (nil, nil): true
        case let (left?, right?): left.arranges(like: right)
        default: false
        }
    }
}

#endif
