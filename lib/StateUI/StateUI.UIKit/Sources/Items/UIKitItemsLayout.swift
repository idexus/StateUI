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

    /// The room an entry keeps along the list before it is measured, down and across (`ItemsCells.estimatedExtent`).
    private static let estimateDown = ItemsCells.estimatedExtent(across: false)
    private static let estimateAcross = ItemsCells.estimatedExtent(across: true)

    /// The layout `layout` says, over the entries `entries` answers as UIKit asks; a list's item swipes to the actions
    /// `swipe` answers for it.
    static func make(
        _ layout: ItemsLayout, entries: @escaping () -> ItemsEntries,
        swipe: @escaping (IndexPath) -> UISwipeActionsConfiguration?
    ) -> UICollectionViewCompositionalLayout {
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
            let section = Self.section(layout, in: environment, swipe: swipe)
            section.boundarySupplementaryItems =
                (sections[index].header == nil ? [] : [supplement(header, across: across, before: true)])
                + (sections[index].footer == nil ? [] : [supplement(footer, across: across, before: false)])
            return section
        }, configuration: configuration)
    }

    /// One group's items as the layout lays them - a list's as UIKit's own list, which swipes an item to its actions.
    /// Design: docs/design/platforms/uikit/items.md#an-items-actions
    private static func section(
        _ layout: ItemsLayout, in environment: any NSCollectionLayoutEnvironment,
        swipe: @escaping (IndexPath) -> UISwipeActionsConfiguration?
    ) -> NSCollectionLayoutSection {
        let width = environment.container.effectiveContentSize.width
        switch layout {
        case .list(let spacing):
            var list = UICollectionLayoutListConfiguration(appearance: .plain)
            list.showsSeparators = false
            list.backgroundColor = .clear
            list.trailingSwipeActionsConfigurationProvider = swipe
            let section = NSCollectionLayoutSection.list(using: list, layoutEnvironment: environment)
            section.interGroupSpacing = spacing
            return section
        case .row(let spacing):
            let size = NSCollectionLayoutSize(widthDimension: .estimated(estimateAcross), heightDimension: .fractionalHeight(1))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            return section
        case .grid(let minimum, let spacing):
            let columns = ItemsGrid.columns(width: width, minimumItemWidth: minimum, spacing: spacing)
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1 / CGFloat(columns)), heightDimension: .estimated(estimateDown)))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(estimateDown)),
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
            ? NSCollectionLayoutSize(widthDimension: .estimated(estimateAcross), heightDimension: .fractionalHeight(1))
            : NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(estimateDown))
        let alignment: NSRectAlignment = across ? (before ? .leading : .trailing) : (before ? .top : .bottom)
        return NSCollectionLayoutBoundarySupplementaryItem(layoutSize: size, elementKind: kind, alignment: alignment)
    }
}
#endif
