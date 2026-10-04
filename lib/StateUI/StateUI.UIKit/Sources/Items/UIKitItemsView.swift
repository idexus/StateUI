// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An ItemsView: UIKit's own collection view over the list's identities, a cell holding each entry's subtree as the
/// collection asks for it (`ItemsCells`). UIKit scrolls, reuses its cells, selects and tells VoiceOver; StateUI
/// builds what a cell holds.
/// Design: docs/design/platforms/uikit/items.md
@MainActor
final class UIKitItemsView: UIView, UICollectionViewDelegate {
    let cells: ItemsCells
    private(set) var collection: UICollectionView
    private var source: UICollectionViewDiffableDataSource<Int, String>!
    private var layout = ItemsLayout.list()
    private var mode = SelectionMode.none

    /// Whether the layout stands the list's own header and footer - which UIKit fixes as the layout is made.
    private var framed = (header: false, footer: false)


    /// Whether the motion of a scroll the tree asks for is left out.
    private let reducesMotion: () -> Bool

    init(cells: ItemsCells, reducesMotion: @escaping () -> Bool) {
        self.cells = cells
        self.reducesMotion = reducesMotion
        collection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        super.init(frame: .zero)
        collection.backgroundColor = .clear
        collection.allowsSelection = false
        collection.delegate = self
        collection.setCollectionViewLayout(UIKitItemsLayout.make(layout) { [cells] in cells.entries }, animated: false)
        addSubview(collection)
        source = makeSource()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitItemsView is made in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if collection.frame != bounds { collection.frame = bounds }
        cells.showing(shownIdentities)
    }

    /// As wide as it is offered and as tall as nothing asks: its room is what its layout gives it.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width.isFinite ? size.width : 0, height: 0)
    }

    // MARK: - What the tree says

    /// The entries, the layout, how many may be chosen and which are.
    func apply(layout: ItemsLayout, mode: SelectionMode) {
        let changes = cells.takeEntries()
        let framed = (header: cells.entries.header != nil, footer: cells.entries.footer != nil)
        if layout != self.layout || framed != self.framed {
            self.layout = layout
            self.framed = framed
            collection.setCollectionViewLayout(UIKitItemsLayout.make(layout) { [cells] in cells.entries }, animated: false)
        }
        if let changes {
            applyEntries(changes)
        }
        if mode != self.mode {
            self.mode = mode
            collection.allowsSelection = mode != .none
            collection.allowsMultipleSelection = mode == .multiple
        }
        select(cells.selected)
    }

    /// The identities as UIKit's snapshot, one section a group; a header or a footer is the section's own.
    private func applyEntries(_ changes: ItemsChanges) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        for (index, section) in cells.entries.sections.enumerated() {
            snapshot.appendSections([index])
            snapshot.appendItems(section.items, toSection: index)
        }
        // A header or a footer the tree added or took away is a change of the layout's shape.
        collection.collectionViewLayout.invalidateLayout()
        source.apply(snapshot, animatingDifferences: !changes.isEmpty && !reducesMotion())
    }

    /// Selects what the tree says is chosen, as the program: nothing is told back.
    private func select(_ chosen: [String]) {
        let wanted = Set(chosen.compactMap { source.indexPath(for: $0) })
        let now = Set(collection.indexPathsForSelectedItems ?? [])
        guard wanted != now else { return }
        ProgramWrite.perform {
            for gone in now.subtracting(wanted) { collection.deselectItem(at: gone, animated: false) }
            for added in wanted.subtracting(now) { collection.selectItem(at: added, animated: false, scrollPosition: []) }
        }
    }

    /// The tree's entries changed: every cell shows the subtree its entry has now (`ItemsCells.childrenChanged`).
    func childrenChanged() {
        cells.childrenChanged()
    }

    /// An entry's size would change: the cell holding it is measured again - none, for an entry still on its way
    /// into a cell, which measures it as it takes it.
    /// Design: docs/design/platforms/uikit/items.md#a-cell
    func remeasure(_ item: MountedElement) {
        guard let identity = cells.identity(of: item) else { return }
        (cells.holding(of: identity) as? UIKitItemHolding)?.forget()
    }

    // MARK: - The cells

    private func makeSource() -> UICollectionViewDiffableDataSource<Int, String> {
        let cell = UICollectionView.CellRegistration<UIKitItemCell, String> { [weak self] cell, _, identity in
            self?.hold(identity, in: cell.holding)
        }
        let source = UICollectionViewDiffableDataSource<Int, String>(collectionView: collection) {
            collection, indexPath, identity in
            collection.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: identity)
        }
        let kinds = [UIKitItemsLayout.header, UIKitItemsLayout.footer, UIKitItemsLayout.listHeader,
                     UIKitItemsLayout.listFooter]
        let registrations = kinds.map { kind in
            UICollectionView.SupplementaryRegistration<UIKitItemSupplement>(elementKind: kind) { [weak self] view, kind, indexPath in
                guard let self, let identity = self.supplement(kind, at: indexPath) else { return self?.cells.endShowing(in: view.holding) ?? () }
                self.hold(identity, in: view.holding)
            }
        }
        source.supplementaryViewProvider = { collection, kind, indexPath in
            guard let registration = zip(kinds, registrations).first(where: { $0.0 == kind })?.1 else { return nil }
            return collection.dequeueConfiguredReusableSupplementary(using: registration, for: indexPath)
        }
        return source
    }

    /// Holds the entry of `identity` in a cell, as the host layer keeps one cell an entry.
    private func hold(_ identity: String, in holding: UIKitItemHolding) {
        holding.across = layout.isAcross
        cells.hold(identity, in: holding)
    }

    /// The identity of the header or footer of `kind` at `indexPath`.
    private func supplement(_ kind: String, at indexPath: IndexPath) -> String? {
        let entries = cells.entries
        switch kind {
        case UIKitItemsLayout.listHeader: return entries.header
        case UIKitItemsLayout.listFooter: return entries.footer
        default:
            guard entries.sections.indices.contains(indexPath.section) else { return nil }
            let section = entries.sections[indexPath.section]
            return kind == UIKitItemsLayout.header ? section.header : section.footer
        }
    }

    /// The identities UIKit shows now.
    private var shownIdentities: [String] {
        collection.indexPathsForVisibleItems.compactMap { source.itemIdentifier(for: $0) }
    }

    // MARK: - What the user does

    /// An item coming on screen holds its entry - UIKit shows again, without asking for it, a cell that ended
    /// showing the item a moment before and let it go - and may be near the end.
    /// Design: docs/design/platforms/uikit/items.md#one-cell-an-entry
    func collectionView(
        _ collection: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath
    ) {
        guard let identity = source.itemIdentifier(for: indexPath) else { return }
        if let holding = (cell as? UIKitItemCell)?.holding {
            holding.across = layout.isAcross
            cells.show(identity, in: holding)
        }
        cells.showing(shownIdentities + [identity])
    }

    func collectionView(
        _ collection: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView,
        forElementKind kind: String, at indexPath: IndexPath
    ) {
        guard let holding = (view as? UIKitItemSupplement)?.holding, let identity = supplement(kind, at: indexPath)
        else { return }
        holding.across = layout.isAcross
        cells.show(identity, in: holding)
    }

    func collectionView(
        _ collection: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath
    ) {
        guard let holding = (cell as? UIKitItemCell)?.holding else { return }
        cells.endShowing(in: holding)
    }

    func collectionView(
        _ collection: UICollectionView, didEndDisplayingSupplementaryView view: UICollectionReusableView,
        forElementOfKind kind: String, at indexPath: IndexPath
    ) {
        guard let holding = (view as? UIKitItemSupplement)?.holding else { return }
        cells.endShowing(in: holding)
    }

    func collectionView(_ collection: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        userChose()
    }

    func collectionView(_ collection: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        userChose()
    }

    func collectionView(_ collection: UICollectionView, performPrimaryActionForItemAt indexPath: IndexPath) {
        guard let identity = source.itemIdentifier(for: indexPath) else { return }
        cells.userActivated(identity)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        cells.showing(shownIdentities)
    }

    /// Tells the tree every item chosen now.
    private func userChose() {
        cells.userChose((collection.indexPathsForSelectedItems ?? []).compactMap { source.itemIdentifier(for: $0) })
    }

    // MARK: - Acts

    /// Scrolls until the item of `identity` stands where `anchor` says, by the host layer's rule
    /// (`ScrollAnchor.place`), within the room the collection's insets leave and within its reach.
    /// Design: docs/design/host/items.md#scrolling-to-an-item
    func scroll(to identity: String, anchor: ScrollAnchor) {
        guard let indexPath = source.indexPath(for: identity),
              let item = collection.layoutAttributesForItem(at: indexPath)?.frame
        else { return }
        let across = layout.isAcross
        let insets = collection.adjustedContentInset
        let (before, after) = across ? (insets.left, insets.right) : (insets.top, insets.bottom)
        let (bounds, size, standing) = (collection.bounds, collection.contentSize, collection.contentOffset)
        let (start, length, side, content, now) = across
            ? (item.minX, item.width, bounds.width, size.width, standing.x)
            : (item.minY, item.height, bounds.height, size.height, standing.y)
        let room = side - before - after
        guard let place = anchor.place(of: start, length: length, in: room, at: now + before) else { return }
        let offset = min(max(-before, place - before), max(-before, content + after - side))
        var point = collection.contentOffset
        if across { point.x = offset } else { point.y = offset }
        collection.setContentOffset(point, animated: !reducesMotion())
    }

    // MARK: - For the tests

    /// The items UIKit holds selected, in the order they show.
    var selectedForTesting: [String] {
        let chosen = Set((collection.indexPathsForSelectedItems ?? []).compactMap { source.itemIdentifier(for: $0) })
        return cells.identities.filter(chosen.contains)
    }

    /// How many items UIKit lets the user choose.
    var modeForTesting: SelectionMode {
        collection.allowsSelection ? (collection.allowsMultipleSelection ? .multiple : .single) : .none
    }

    /// The item at `place` among all the items chosen, or let go where it was chosen and many may be - as a tap does.
    func chooseForTesting(_ place: Int) {
        let items = cells.entries.sections.flatMap(\.items)
        guard collection.allowsSelection, items.indices.contains(place),
              let indexPath = source.indexPath(for: items[place]) else { return }
        if collection.indexPathsForSelectedItems?.contains(indexPath) == true, collection.allowsMultipleSelection {
            collection.deselectItem(at: indexPath, animated: false)
            collectionView(collection, didDeselectItemAt: indexPath)
        } else {
            collection.selectItem(at: indexPath, animated: false, scrollPosition: [])
            collectionView(collection, didSelectItemAt: indexPath)
        }
    }

    /// The item of `identity` opened, as a tap on it does.
    func activateForTesting(_ identity: String) {
        guard let indexPath = source.indexPath(for: identity) else { return }
        collectionView(collection, performPrimaryActionForItemAt: indexPath)
    }

    /// Scrolls to `target`, kept within reach.
    func scrollForTesting(to target: Point) {
        collection.layoutIfNeeded()
        let size = collection.contentSize
        let bounds = collection.bounds.size
        collection.setContentOffset(CGPoint(
            x: min(max(0, target.x), max(0, size.width - bounds.width)),
            y: min(max(0, target.y), max(0, size.height - bounds.height))), animated: false)
        collection.layoutIfNeeded()
    }
}
#endif
