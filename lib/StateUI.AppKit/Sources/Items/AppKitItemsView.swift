// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The collection view of an ItemsView: a double-click or Return opens the item, as on a Mac.
@MainActor
final class AppKitCollection: NSCollectionView {
    var onActivated: ((IndexPath) -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, let indexPath = indexPathForItem(at: convert(event.locationInWindow, from: nil)) {
            onActivated?(indexPath)
            return
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 36 || event.keyCode == 76, let chosen = selectionIndexPaths.min() else {
            return super.keyDown(with: event)
        }
        onActivated?(chosen)
    }
}

/// An ItemsView: AppKit's own collection view over the list's identities, a cell holding each entry's subtree as the
/// collection asks for it (`ItemsCells`). AppKit scrolls, reuses its cells, selects and tells VoiceOver; StateUI
/// builds what a cell holds.
/// Design: docs/design/platforms/appkit/items.md
@MainActor
final class AppKitItemsView: NSView, AppKitRoom, AppKitWidthConstrainedMeasuring, NSCollectionViewDelegate {
    let cells: ItemsCells
    let collection = AppKitCollection()
    private let scroller = NSScrollView()
    private var source: NSCollectionViewDiffableDataSource<Int, String>!
    private var layoutShape = ItemsLayout.list()
    private var mode = SelectionMode.none
    private var framed = (header: false, footer: false)
    /// The entries whose cells ask for another size, measured again on the next layout.
    private var resizing: Set<String> = []
    private let reducesMotion: () -> Bool

    override var isFlipped: Bool { true }

    init(cells: ItemsCells, reducesMotion: @escaping () -> Bool) {
        self.cells = cells
        self.reducesMotion = reducesMotion
        super.init(frame: .zero)
        collection.isSelectable = false
        collection.allowsEmptySelection = true
        collection.backgroundColors = [.clear]
        collection.delegate = self
        lay(layoutShape)
        collection.onActivated = { [weak self] indexPath in
            guard let identity = self?.source.itemIdentifier(for: indexPath) else { return }
            self?.cells.userActivated(identity)
        }
        scroller.documentView = collection
        scroller.hasVerticalScroller = true
        scroller.drawsBackground = false
        scroller.autoresizingMask = [.width, .height]
        scroller.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: scroller.contentView)
        addSubview(scroller)
        source = makeSource()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitItemsView is made in code")
    }

    private static let item = NSUserInterfaceItemIdentifier("StateUI.item")

    /// As wide as it is offered and as tall as nothing asks: its room is what its layout gives it.
    func fittingContentSize(width: CGFloat?) -> NSSize {
        NSSize(width: width ?? 0, height: 0)
    }

    override func layout() {
        super.layout()
        if scroller.frame != bounds { scroller.frame = bounds }
        measureResized()
        cells.showing(shownIdentities)
    }

    // MARK: - What the tree says

    /// The entries, the layout, how many may be chosen and which are.
    func apply(layout: ItemsLayout, mode: SelectionMode) {
        let changes = cells.takeEntries()
        let framed = (header: cells.entries.header != nil, footer: cells.entries.footer != nil)
        if layout != layoutShape || framed != self.framed {
            layoutShape = layout
            self.framed = framed
            scroller.hasVerticalScroller = !layout.isAcross
            scroller.hasHorizontalScroller = layout.isAcross
            lay(layout)
        }
        if changes != nil {
            var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
            for (index, section) in cells.entries.sections.enumerated() {
                snapshot.appendSections([index])
                snapshot.appendItems(section.items, toSection: index)
            }
            source.apply(snapshot, animatingDifferences: changes?.isEmpty == false && !reducesMotion())
        }
        if mode != self.mode {
            self.mode = mode
            collection.isSelectable = mode != .none
            collection.allowsMultipleSelection = mode == .multiple
        }
        select(cells.selected)
    }

    /// Lays the collection out as `layout` says, and tells it the cells it makes: a new layout forgets the
    /// registrations made before it.
    /// Design: docs/design/platforms/appkit/items.md#the-layout
    private func lay(_ layout: ItemsLayout) {
        collection.collectionViewLayout = AppKitItemsLayout.make(layout) { [cells] in cells.entries }
        collection.register(AppKitItemCell.self, forItemWithIdentifier: Self.item)
        for kind in AppKitItemsLayout.kinds {
            collection.register(
                AppKitItemSupplement.self, forSupplementaryViewOfKind: kind,
                withIdentifier: NSUserInterfaceItemIdentifier(kind))
        }
    }

    /// Selects what the tree says is chosen, as the program: nothing is told back.
    private func select(_ chosen: [String]) {
        let wanted = Set(chosen.compactMap { source.indexPath(for: $0) })
        guard wanted != collection.selectionIndexPaths else { return }
        ProgramWrite.perform { collection.selectionIndexPaths = wanted }
    }

    /// The tree's entries changed: every cell shows the subtree its entry has now (`ItemsCells.childrenChanged`).
    func childrenChanged() {
        for case let holding as AppKitItemHolding in cells.childrenChanged() { resized(holding) }
    }

    /// The cell of `holding` may ask for another size: measured again where it does - its item alone. AppKit tells
    /// a cell its size changed as it merely places it, and a whole invalidation makes it ask for every cell again.
    /// Design: docs/design/platforms/appkit/items.md#a-cell
    private func resized(_ holding: AppKitItemHolding) {
        guard let identity = holding.identity, let indexPath = source.indexPath(for: identity),
              let cell = collection.item(at: indexPath), holding.asksAnotherSize(than: cell.view.frame.size)
        else { return }
        resizing.insert(identity)
        needsLayout = true
    }

    /// Asks the layout again for the cells whose entries changed size.
    private func measureResized() {
        guard !resizing.isEmpty else { return }
        let paths = Set(resizing.compactMap { source.indexPath(for: $0) })
        resizing = []
        guard !paths.isEmpty else { return }
        let context = NSCollectionViewLayoutInvalidationContext()
        context.invalidateItems(at: paths)
        collection.collectionViewLayout?.invalidateLayout(with: context)
    }

    // MARK: - The cells

    private func makeSource() -> NSCollectionViewDiffableDataSource<Int, String> {
        let source = NSCollectionViewDiffableDataSource<Int, String>(collectionView: collection) {
            [weak self] collection, indexPath, identity in
            guard let cell = collection.makeItem(withIdentifier: Self.item, for: indexPath) as? AppKitItemCell
            else { return nil }
            self?.hold(identity, in: cell.holding, of: cell.view)
            return cell
        }
        source.supplementaryViewProvider = { [weak self] collection, kind, indexPath in
            guard let view = collection.makeSupplementaryView(
                ofKind: kind, withIdentifier: NSUserInterfaceItemIdentifier(kind), for: indexPath) as? AppKitItemSupplement
            else { return nil }
            if let self, let identity = self.supplement(kind, at: indexPath) {
                self.hold(identity, in: view.holding, of: view)
            }
            return view
        }
        return source
    }

    /// Holds the entry of `identity` in a cell, as the host layer keeps one cell an entry.
    private func hold(_ identity: String, in holding: AppKitItemHolding, of view: NSView) {
        holding.across = layoutShape.isAcross
        if let cellView = view as? AppKitItemCellView {
            cellView.holding = holding
            cellView.resized = { [weak self] in self?.resized(holding) }
        }
        cells.hold(identity, in: holding)
    }

    /// The identity of the header or footer of `kind` at `indexPath`.
    private func supplement(_ kind: String, at indexPath: IndexPath) -> String? {
        let entries = cells.entries
        switch kind {
        case AppKitItemsLayout.listHeader: return entries.header
        case AppKitItemsLayout.listFooter: return entries.footer
        default:
            guard entries.sections.indices.contains(indexPath.section) else { return nil }
            let section = entries.sections[indexPath.section]
            return kind == AppKitItemsLayout.header ? section.header : section.footer
        }
    }

    /// The identities AppKit shows now.
    private var shownIdentities: [String] {
        collection.indexPathsForVisibleItems().compactMap { source.itemIdentifier(for: $0) }
    }

    @objc private func scrolled() {
        cells.showing(shownIdentities)
    }

    // MARK: - What the user does

    func collectionView(
        _ collection: NSCollectionView, willDisplay item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath
    ) {
        guard let identity = source.itemIdentifier(for: indexPath), let cell = item as? AppKitItemCell else { return }
        cell.holding.across = layoutShape.isAcross
        cells.show(identity, in: cell.holding)
        cells.showing(shownIdentities + [identity])
    }

    func collectionView(
        _ collection: NSCollectionView, didEndDisplaying item: NSCollectionViewItem,
        forRepresentedObjectAt indexPath: IndexPath
    ) {
        guard let cell = item as? AppKitItemCell else { return }
        cells.endShowing(in: cell.holding)
    }

    func collectionView(
        _ collection: NSCollectionView, willDisplaySupplementaryView view: NSView,
        forElementKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath
    ) {
        guard let holding = (view as? AppKitItemSupplement)?.holding, let identity = supplement(kind, at: indexPath)
        else { return }
        cells.show(identity, in: holding)
    }

    func collectionView(
        _ collection: NSCollectionView, didEndDisplayingSupplementaryView view: NSView,
        forElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath
    ) {
        guard let holding = (view as? AppKitItemSupplement)?.holding else { return }
        cells.endShowing(in: holding)
    }

    func collectionView(_ collection: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        userChose()
    }

    func collectionView(_ collection: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        userChose()
    }

    /// Tells the tree every item chosen now.
    private func userChose() {
        cells.userChose(collection.selectionIndexPaths.compactMap { source.itemIdentifier(for: $0) })
    }

    // MARK: - Acts

    /// Scrolls until the item of `identity` stands where `anchor` says; nearest scrolls only where it is not wholly
    /// in view, the shorter way. The place is worked out from the item's frame as the layout holds it once the cells
    /// around it are measured - AppKit's own scroll to an item goes by the sizes it estimated.
    /// Design: docs/design/platforms/appkit/items.md#scrolling-to-an-item
    func scroll(to identity: String, anchor: ScrollAnchor) {
        guard let indexPath = source.indexPath(for: identity) else { return }
        let clip = scroller.contentView
        guard reducesMotion() else {
            guard let target = target(of: indexPath, anchor: anchor) else { return }
            NSAnimationContext.runAnimationGroup({ _ in
                clip.animator().setBoundsOrigin(target)
            }, completionHandler: { [weak self] in
                // AppKit ends an animation group on the main thread.
                MainActor.assumeIsolated { self?.settle(indexPath, anchor: anchor) }
            })
            return
        }
        collection.scrollToItems(at: [indexPath], scrollPosition: layoutShape.isAcross ? .left : .top)
        layoutSubtreeIfNeeded()
        settle(indexPath, anchor: anchor)
    }

    /// Stands the item where `anchor` says, from the frames the layout holds now.
    private func settle(_ indexPath: IndexPath, anchor: ScrollAnchor) {
        guard let target = target(of: indexPath, anchor: anchor) else { return }
        scroller.contentView.scroll(to: target)
        scroller.reflectScrolledClipView(scroller.contentView)
        layoutSubtreeIfNeeded()
        scrolled()
    }

    /// Where the clip view stands for the item at `indexPath` to stand where `anchor` says, within reach; nil where
    /// the item is nowhere, or where it stands wholly in view and the anchor is nearest.
    private func target(of indexPath: IndexPath, anchor: ScrollAnchor) -> NSPoint? {
        guard let item = collection.layoutAttributesForItem(at: indexPath)?.frame else { return nil }
        let visible = scroller.contentView.bounds
        let size = collection.frame.size
        let across = layoutShape.isAcross
        let (start, length, room, now) = across
            ? (item.minX, item.width, visible.width, visible.minX)
            : (item.minY, item.height, visible.height, visible.minY)
        guard let place = anchor.place(of: start, length: length, in: room, at: now) else { return nil }
        let reach = max(0, (across ? size.width : size.height) - room)
        let offset = min(max(0, place), reach)
        return across ? NSPoint(x: offset, y: visible.minY) : NSPoint(x: visible.minX, y: offset)
    }

    // MARK: - For the tests

    /// The items AppKit holds selected, in the order they show.
    var selectedForTesting: [String] {
        let chosen = Set(collection.selectionIndexPaths.compactMap { source.itemIdentifier(for: $0) })
        return cells.identities.filter(chosen.contains)
    }

    /// How many items AppKit lets the user choose.
    var modeForTesting: SelectionMode {
        collection.isSelectable ? (collection.allowsMultipleSelection ? .multiple : .single) : .none
    }

    /// The item at `place` among all the items chosen, or let go where it was chosen and many may be - as a click does.
    func chooseForTesting(_ place: Int) {
        let items = cells.entries.sections.flatMap(\.items)
        guard collection.isSelectable, items.indices.contains(place),
              let indexPath = source.indexPath(for: items[place]) else { return }
        if collection.selectionIndexPaths.contains(indexPath), collection.allowsMultipleSelection {
            collection.deselectItems(at: [indexPath])
            collectionView(collection, didDeselectItemsAt: [indexPath])
        } else {
            let before = collection.allowsMultipleSelection ? collection.selectionIndexPaths : []
            collection.selectionIndexPaths = before.union([indexPath])
            collectionView(collection, didSelectItemsAt: [indexPath])
        }
    }

    /// The item of `identity` opened, as a double-click on it does.
    func activateForTesting(_ identity: String) {
        guard let indexPath = source.indexPath(for: identity) else { return }
        collection.onActivated?(indexPath)
    }

    /// Scrolls to `target`, kept within reach.
    func scrollForTesting(to target: Point) {
        layoutSubtreeIfNeeded()
        let size = collection.frame.size
        let visible = scroller.contentView.bounds.size
        scroller.contentView.scroll(to: NSPoint(
            x: min(max(0, target.x), max(0, size.width - visible.width)),
            y: min(max(0, target.y), max(0, size.height - visible.height))))
        scroller.reflectScrolledClipView(scroller.contentView)
        layoutSubtreeIfNeeded()
        scrolled()
    }
}
#endif
