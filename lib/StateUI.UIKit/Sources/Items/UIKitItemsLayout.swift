// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An ItemsView's layout as UIKit's compositional layout: a list down, a row across, or a grid of the columns its
/// width holds (`ItemsGrid`); each entry sized by what it asks for, headers and footers standing before and after.
/// Design: docs/design/platforms/uikit/items.md#the-layout
@MainActor
enum UIKitItemsLayout {
    static let header = "StateUI.header"
    static let footer = "StateUI.footer"
    static let listHeader = "StateUI.listHeader"
    static let listFooter = "StateUI.listFooter"

    /// The layout `layout` says, over the entries `entries` answers as UIKit asks.
    static func make(_ layout: ItemsLayout, entries: @escaping () -> ItemsEntries) -> UICollectionViewCompositionalLayout {
        let across = layout.isAcross
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = across ? .horizontal : .vertical
        let shown = entries()
        configuration.boundarySupplementaryItems =
            (shown.header == nil ? [] : [supplement(listHeader, across: across, before: true)])
            + (shown.footer == nil ? [] : [supplement(listFooter, across: across, before: false)])

        return UICollectionViewCompositionalLayout(sectionProvider: { index, environment in
            let sections = entries().sections
            guard sections.indices.contains(index) else { return nil }
            let section = Self.section(layout, width: environment.container.effectiveContentSize.width)
            section.boundarySupplementaryItems =
                (sections[index].header == nil ? [] : [supplement(header, across: across, before: true)])
                + (sections[index].footer == nil ? [] : [supplement(footer, across: across, before: false)])
            return section
        }, configuration: configuration)
    }

    /// One group's items as the layout lays them.
    private static func section(_ layout: ItemsLayout, width: CGFloat) -> NSCollectionLayoutSection {
        switch layout {
        case .list(let spacing):
            let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            return section
        case .row(let spacing):
            let size = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .fractionalHeight(1))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            return section
        case .grid(let minimum, let spacing):
            let columns = ItemsGrid.columns(width: width, minimumItemWidth: minimum, spacing: spacing)
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1 / CGFloat(columns)), heightDimension: .estimated(44)))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)),
                repeatingSubitem: item, count: columns)
            group.interItemSpacing = .fixed(spacing)
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            return section
        }
    }

    /// A header or a footer of kind `kind`, before the items or after them.
    private static func supplement(
        _ kind: String, across: Bool, before: Bool
    ) -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = across
            ? NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .fractionalHeight(1))
            : NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44))
        let alignment: NSRectAlignment = across ? (before ? .leading : .trailing) : (before ? .top : .bottom)
        return NSCollectionLayoutBoundarySupplementaryItem(layoutSize: size, elementKind: kind, alignment: alignment)
    }
}
#endif
