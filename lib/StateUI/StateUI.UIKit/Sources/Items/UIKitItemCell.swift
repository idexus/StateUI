// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a cell of an ItemsView holds: one entry's subtree, placed by the layer's arithmetic, and the size it asks
/// for across the cell's fixed side.
/// Design: docs/design/platforms/uikit/items.md#a-cell
@MainActor
final class UIKitItemHolding: ItemsHolding {
    /// The identity held, where the cell holds one.
    private(set) var identity: String?

    /// The entry whose subtree the cell shows, where it shows one.
    private(set) weak var shown: MountedElement?

    /// Whether the cell is as tall as the list, and asks for its width - in a row.
    var across = false

    private let holder = UIKitSingleChildView()

    /// The cell, which UIKit measures again when told its size may have changed.
    private weak var cell: UIView?

    init(in content: UIView, of cell: UIView) {
        self.cell = cell
        holder.frame = content.bounds
        holder.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        content.addSubview(holder)
    }

    /// Holds the entry of `identity`: its subtree where it is built, and nothing until it is.
    func hold(_ identity: String, _ item: MountedElement?) {
        self.identity = identity
        guard item !== shown || holder.items.isEmpty != (item == nil) else { return }
        shown = item
        holder.setItems(item?.uiKit.layoutItem.map { [$0] } ?? [])
        if item != nil { forget() }
    }

    /// Lets the entry go: its view leaves the cell.
    func letGo() {
        identity = nil
        shown = nil
        holder.setItems([])
    }

    /// The entry's size would change: UIKit measures the cell again (its self-sizing invalidation).
    /// Design: docs/design/platforms/uikit/items.md#a-cell
    func forget() {
        holder.forgetMeasurements()
        holder.setNeedsLayout()
        cell?.invalidateIntrinsicContentSize()
    }

    /// The size the entry asks for in `attributes`: its height at the cell's width, or its width at the cell's
    /// height in a row. A cell whose entry is still on its way keeps the size UIKit estimated: a size measured of
    /// nothing would fold its whole row away.
    func fitting(_ attributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        guard shown != nil, !holder.items.isEmpty, let fitted = attributes.copy() as? UICollectionViewLayoutAttributes else {
            return attributes
        }
        if across {
            fitted.size.width = max(1, holder.measuredSize(width: nil).width)
        } else {
            fitted.size.height = max(1, holder.measuredSize(width: attributes.size.width).height)
        }
        return fitted
    }
}

/// A cell of an ItemsView, holding one item - UIKit's own list cell, which shows the user's choice and touch.
@MainActor
final class UIKitItemCell: UICollectionViewCell {
    private(set) lazy var holding = UIKitItemHolding(in: contentView, of: self)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundConfiguration = .listCell()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitItemCell is made in code")
    }

    override func preferredLayoutAttributesFitting(
        _ attributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        holding.fitting(attributes)
    }
}

/// A header or a footer of an ItemsView or of one of its groups.
@MainActor
final class UIKitItemSupplement: UICollectionReusableView {
    private(set) lazy var holding = UIKitItemHolding(in: self, of: self)

    override func preferredLayoutAttributesFitting(
        _ attributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        holding.fitting(attributes)
    }
}
#endif
