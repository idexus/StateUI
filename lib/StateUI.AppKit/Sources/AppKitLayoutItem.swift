// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

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

    /// The view's size for the width offered, margin included in the offer, its stated sizes and bounds applied.
    func fittingSize(width availableWidth: CGFloat? = nil) -> NSSize {
        let available = availableWidth.map { max(0, $0 - margin.left - margin.right) }
        let measured: NSSize
        if let measurable = view as? AppKitWidthConstrainedMeasuring {
            measured = measurable.fittingContentSize(width: available)
        } else {
            if let label = view as? NSTextField, let available, available.isFinite {
                label.preferredMaxLayoutWidth = available
            }
            measured = view.fittingSize
        }
        return NSSize(
            width: values.boundedWidth(values.width ?? Double(measured.width)),
            height: values.boundedHeight(values.height ?? Double(measured.height)))
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
