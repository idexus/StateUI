// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a cell of an ItemsView holds: one entry's subtree, placed by the layer's arithmetic, and the size it asks
/// for across the cell's fixed side.
/// Design: docs/design/platforms/appkit/items.md#a-cell
@MainActor
final class AppKitItemHolding: ItemsHolding {
    /// The identity held, where the cell holds one.
    private(set) var identity: String?

    /// The entry whose subtree the cell shows, where it shows one.
    private(set) weak var shown: MountedElement?

    /// Whether the cell is as tall as the list, and asks for its width - in a row.
    var across = false

    /// Whether the cell is taking an entry: what that asks of the list's measure, the cell's own measure answers.
    private(set) var taking = false

    private let holder = AppKitSingleChildView()

    init(in content: NSView) {
        holder.frame = content.bounds
        holder.autoresizingMask = [.width, .height]
        content.addSubview(holder)
    }

    func hold(_ identity: String, _ item: MountedElement?) {
        self.identity = identity
        guard item !== shown || (holder.item == nil) != (item == nil) else { return }
        taking = true
        defer { taking = false }
        shown = item
        holder.setItem(item?.appKit.layoutItem)
    }

    func letGo() {
        identity = nil
        shown = nil
        holder.setItem(nil)
    }

    /// Whether the entry asks for another size than the cell stands at `size` - the side its layout measures.
    func asksAnotherSize(than size: NSSize) -> Bool {
        guard shown != nil, holder.item != nil else { return false }
        if across { return abs(holder.fittingContentSize(width: nil).width - size.width) > 0.5 }
        return abs(holder.fittingContentSize(width: size.width).height - size.height) > 0.5
    }

    /// The size the entry asks for in `attributes`: its height at the cell's width, or its width at the cell's
    /// height in a row. A cell whose entry is still on its way keeps the size AppKit estimated: a size measured of
    /// nothing would fold its whole row away.
    func fitting(_ attributes: NSCollectionViewLayoutAttributes) -> NSCollectionViewLayoutAttributes {
        guard shown != nil, holder.item != nil, let fitted = attributes.copy() as? NSCollectionViewLayoutAttributes
        else { return attributes }
        if across {
            fitted.size.width = max(1, holder.fittingContentSize(width: nil).width)
        } else {
            fitted.size.height = max(1, holder.fittingContentSize(width: attributes.size.width).height)
        }
        return fitted
    }
}

/// The view of a cell: an entry changing size inside it tells the list - never while the cell takes an entry, which
/// the layout measures anyway.
@MainActor
final class AppKitItemCellView: NSView {
    var resized: (() -> Void)?
    weak var holding: AppKitItemHolding?

    /// Whether the cell's item is chosen, drawn as AppKit draws a chosen item - in the accent while the list holds the
    /// keyboard.
    var chosen = false {
        didSet { if chosen != oldValue { needsDisplay = true } }
    }

    var emphasized = true {
        didSet { if emphasized != oldValue { needsDisplay = true } }
    }

    override var isFlipped: Bool { true }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        if holding?.taking != true { resized?() }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard chosen else { return }
        (emphasized ? NSColor.selectedContentBackgroundColor : NSColor.unemphasizedSelectedContentBackgroundColor)
            .setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
    }
}

/// A cell of an ItemsView, holding one item.
@MainActor
final class AppKitItemCell: NSCollectionViewItem {
    private(set) lazy var holding = AppKitItemHolding(in: view)

    override func loadView() {
        view = AppKitItemCellView()
    }

    override var isSelected: Bool {
        didSet { (view as? AppKitItemCellView)?.chosen = isSelected }
    }

    override func preferredLayoutAttributesFitting(
        _ attributes: NSCollectionViewLayoutAttributes
    ) -> NSCollectionViewLayoutAttributes {
        holding.fitting(attributes)
    }
}

/// A header or a footer of an ItemsView or of one of its groups.
@MainActor
final class AppKitItemSupplement: NSView, NSCollectionViewElement {
    private(set) lazy var holding = AppKitItemHolding(in: self)

    override var isFlipped: Bool { true }

    func preferredLayoutAttributesFitting(
        _ attributes: NSCollectionViewLayoutAttributes
    ) -> NSCollectionViewLayoutAttributes {
        holding.fitting(attributes)
    }
}
#endif
