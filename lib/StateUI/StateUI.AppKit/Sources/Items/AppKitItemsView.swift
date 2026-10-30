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
final class AppKitItemsView: NSView, AppKitRoom, AppKitWidthConstrainedMeasuring, NSCollectionViewDelegate,
    AppKitPageScroller {
    let cells: ItemsCells
    let collection = AppKitCollection()
    private let scroller = NSScrollView()
    private var source: NSCollectionViewDiffableDataSource<String, String>!
    private var layoutShape = ItemsLayout.list()
    private var mode = SelectionMode.none
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
        // Design: docs/design/platforms/appkit/views.md#scroll-bars
        scroller.scrollerStyle = .overlay
        scroller.documentView = collection
        scroller.hasVerticalScroller = true
        scroller.drawsBackground = false
        scroller.autoresizingMask = [.width, .height]
        scroller.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: scroller.contentView)
        NotificationCenter.default.addObserver(
            self, selector: #selector(userScrolls), name: NSScrollView.willStartLiveScrollNotification, object: scroller)
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
        let resized = scroller.frame.size != bounds.size
        if scroller.frame != bounds { scroller.frame = bounds }
        measureResized()
        cells.showing(shownIdentities)
        if resized { roomChanged() }
    }

    // MARK: - A page's scroller

    /// What the list keeps clear of the bars over it, where it is its page's scroller; its offsets are counted from
    /// its first item clear of them.
    private var clearance = Clearance.none

    /// Keeps `clearance` clear: its first and last items scroll out from under the bars, its end kept where they
    /// grow (`ScrollArithmetic.keptAtEnd`), and the item the program scrolled to stood again in the room they leave.
    /// Design: docs/design/host/layout.md#a-bar-at-the-foot
    func keepClear(_ clearance: Clearance) {
        guard clearance != self.clearance else { return }
        let before = standing
        self.clearance = clearance
        scroller.automaticallyAdjustsContentInsets = false
        scroller.contentInsets = NSEdgeInsets(
            top: clearance.top, left: clearance.left, bottom: clearance.bottom, right: clearance.right)
        let end = ScrollArithmetic.keptAtEnd(before.offset, reach: before.reach, now: standing.reach)
        stand(at: end ?? before.offset)
        roomChanged()
    }

    var standingChanged: (() -> Void)?

    var standing: (offset: Point, reach: Point) {
        let origin = scroller.contentView.bounds.origin
        let size = collection.frame.size
        let viewport = scroller.contentView.bounds.size
        let reach = Point(
            x: max(0, size.width + clearance.left + clearance.right - viewport.width),
            y: max(0, size.height + clearance.top + clearance.bottom - viewport.height))
        return (SafeAreaArithmetic.offset(native: Point(x: origin.x, y: origin.y), clearance: clearance), reach)
    }

    /// Stands the list at `offset`, counted from its first item kept clear.
    private func stand(at offset: Point) {
        let native = SafeAreaArithmetic.native(offset: offset, clearance: clearance)
        scroller.contentView.scroll(to: NSPoint(x: native.x, y: native.y))
        scroller.reflectScrolledClipView(scroller.contentView)
    }

    /// The list's room changed - its size, or what it keeps clear of the bars over it: the item the program scrolled
    /// to stands again where it put it (`ItemsCells.roomChanged`), a glide going on there.
    /// Design: docs/design/platforms/appkit/items.md#scrolling-to-an-item
    private func roomChanged() {
        guard let target = cells.roomChanged(), let indexPath = source.indexPath(for: target.identity) else { return }
        layoutSubtreeIfNeeded()
        guard let point = self.target(of: indexPath, anchor: target.anchor) else { return }
        if gliding { glide(to: point) } else {
            scroller.contentView.scroll(to: point)
            scroller.reflectScrolledClipView(scroller.contentView)
        }
    }

    // MARK: - What the tree says

    /// The entries, the layout, how many may be chosen and which are.
    func apply(layout: ItemsLayout, mode: SelectionMode) {
        let changes = cells.takeEntries()
        if layout != layoutShape {
            layoutShape = layout
            scroller.hasVerticalScroller = !layout.isAcross
            scroller.hasHorizontalScroller = layout.isAcross
            lay(layout)
        }
        if changes != nil {
            // The list's own header and footer each stand alone in a section of its own, known by their identities.
            // Design: docs/design/platforms/appkit/items.md#the-layout
            let entries = cells.entries
            var snapshot = NSDiffableDataSourceSnapshot<String, String>()
            for content in AppKitItemsLayout.sections(of: entries) {
                switch content {
                case .listHeader(let identity), .listFooter(let identity): snapshot.appendSections([identity])
                case .group(let group):
                    snapshot.appendSections([entries.sections[group].identity])
                    snapshot.appendItems(entries.sections[group].items, toSection: entries.sections[group].identity)
                }
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

    /// The tree's entries changed: every cell shows the subtree its entry has now (`ItemsCells.childrenChanged`), and
    /// the item the program scrolled to stands again from the cells measured.
    func childrenChanged() {
        for case let holding as AppKitItemHolding in cells.childrenChanged() { resized(holding) }
        guard cells.scrollTarget != nil, !gliding else { return }
        layoutSubtreeIfNeeded()
        settle()
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

    private func makeSource() -> NSCollectionViewDiffableDataSource<String, String> {
        let source = NSCollectionViewDiffableDataSource<String, String>(collectionView: collection) {
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
        let contents = AppKitItemsLayout.sections(of: entries)
        guard contents.indices.contains(indexPath.section) else { return nil }
        switch (kind, contents[indexPath.section]) {
        case (AppKitItemsLayout.listHeader, .listHeader(let identity)): return identity
        case (AppKitItemsLayout.listFooter, .listFooter(let identity)): return identity
        case (AppKitItemsLayout.header, .group(let group)): return entries.sections[group].header
        case (AppKitItemsLayout.footer, .group(let group)): return entries.sections[group].footer
        default: return nil
        }
    }

    /// The identities AppKit shows now.
    private var shownIdentities: [String] {
        collection.indexPathsForVisibleItems().compactMap { source.itemIdentifier(for: $0) }
    }

    @objc private func scrolled() {
        cells.showing(shownIdentities)
        standingChanged?()
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
        cells.scroll(to: identity, anchor: anchor)
        glides += 1
        gliding = false
        guard !ItemsScrollTarget.glides(reducingMotion: reducesMotion()) else {
            guard let target = target(of: indexPath, anchor: anchor) else { return }
            gliding = true
            return glide(to: target)
        }
        collection.scrollToItems(at: [indexPath], scrollPosition: layoutShape.isAcross ? .left : .top)
        layoutSubtreeIfNeeded()
        settle()
    }

    /// Glides the clip view to `target`, the item stood again as the glide ends - unless another glide, or the user,
    /// took over.
    private func glide(to target: NSPoint) {
        glides += 1
        let glide = glides
        NSAnimationContext.runAnimationGroup({ _ in
            scroller.contentView.animator().setBoundsOrigin(target)
        }, completionHandler: { [weak self] in
            // AppKit ends an animation group on the main thread.
            MainActor.assumeIsolated {
                guard let self, glide == self.glides else { return }
                self.gliding = false
                self.settle()
            }
        })
    }

    /// Whether a scroll the program asked for glides now, which stands its item again as it stops; and how many
    /// glides began, so a glide another took over stands nothing.
    private var gliding = false
    private var glides = 0

    /// Stands the item the program scrolled to where its anchor says, from the frames the layout holds now - and
    /// so after every pass that brings cells their entries, while the host layer holds it.
    /// Design: docs/design/platforms/appkit/items.md#scrolling-to-an-item
    private func settle() {
        guard !gliding, let scrolledTo = cells.laidOut(), let indexPath = source.indexPath(for: scrolledTo.identity),
              let target = target(of: indexPath, anchor: scrolledTo.anchor)
        else { return }
        scroller.contentView.scroll(to: target)
        scroller.reflectScrolledClipView(scroller.contentView)
        layoutSubtreeIfNeeded()
        scrolled()
    }

    /// The user takes the list: where it stands is theirs.
    @objc private func userScrolls() {
        glides += 1
        gliding = false
        cells.userScrolled()
    }

    /// Where the clip view stands for the item at `indexPath` to stand where `anchor` says, within reach; nil where
    /// the item is nowhere, or where it stands wholly in view and the anchor is nearest.
    private func target(of indexPath: IndexPath, anchor: ScrollAnchor) -> NSPoint? {
        guard let item = collection.layoutAttributesForItem(at: indexPath)?.frame else { return nil }
        let visible = scroller.contentView.bounds
        let size = collection.frame.size
        let across = layoutShape.isAcross
        // Within the room the bars over the list leave it, its offsets counted from the clip view's.
        let (before, after) = across ? (clearance.left, clearance.right) : (clearance.top, clearance.bottom)
        let (start, length, side, now) = across
            ? (item.minX, item.width, visible.width, visible.minX)
            : (item.minY, item.height, visible.height, visible.minY)
        let room = side - before - after
        guard let place = anchor.place(of: start, length: length, in: room, at: now + before) else { return nil }
        let content = across ? size.width : size.height
        let offset = min(max(-before, place - before), max(-before, content + after - side))
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
