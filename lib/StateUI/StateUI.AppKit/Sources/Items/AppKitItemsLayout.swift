// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An ItemsView's layout as AppKit's compositional layout: a list down, a row across, or a grid of the columns its
/// width holds (`ItemsGrid`); each entry sized by what it asks for, headers and footers standing before and after.
/// Design: docs/design/platforms/appkit/items.md#the-layout
@MainActor
enum AppKitItemsLayout {
    static let header = "StateUI.header"
    static let footer = "StateUI.footer"
    static let listHeader = "StateUI.listHeader"
    static let listFooter = "StateUI.listFooter"
    static let kinds = [header, footer, listHeader, listFooter]

    /// What one of the collection's sections holds: the list's own header or footer of an identity, each alone in a
    /// section of its own known by it, or a group.
    /// Design: docs/design/platforms/appkit/items.md#the-layout
    enum SectionContent: Equatable {
        case listHeader(String)
        case group(Int)
        case listFooter(String)
    }

    /// The collection's sections for `entries`, in order.
    static func sections(of entries: ItemsEntries) -> [SectionContent] {
        (entries.header.map { [.listHeader($0)] } ?? []) + entries.sections.indices.map { .group($0) }
            + (entries.footer.map { [.listFooter($0)] } ?? [])
    }

    /// The layout `layout` says, over the entries `entries` answers as AppKit asks.
    static func make(_ layout: ItemsLayout, entries: @escaping () -> ItemsEntries) -> NSCollectionViewCompositionalLayout {
        let across = layout.isAcross
        let configuration = NSCollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = across ? .horizontal : .vertical

        return NSCollectionViewCompositionalLayout(sectionProvider: { index, environment in
            let entries = entries()
            let contents = sections(of: entries)
            guard contents.indices.contains(index) else { return nil }
            let section = Self.section(layout, width: environment.container.effectiveContentSize.width)
            switch contents[index] {
            case .listHeader:
                section.boundarySupplementaryItems = [supplement(listHeader, across: across, before: true)]
            case .listFooter:
                section.boundarySupplementaryItems = [supplement(listFooter, across: across, before: false)]
            case .group(let group):
                section.boundarySupplementaryItems =
                    (entries.sections[group].header == nil ? [] : [supplement(header, across: across, before: true)])
                    + (entries.sections[group].footer == nil ? [] : [supplement(footer, across: across, before: false)])
            }
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
                subitem: item, count: columns)
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
