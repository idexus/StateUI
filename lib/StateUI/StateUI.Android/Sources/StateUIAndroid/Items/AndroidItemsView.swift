// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// An ItemsView: AndroidX's recycler over the list's identities, in the relay's `StateUIItemsView`, a cell holding
/// each entry's subtree as the recycler binds it (`ItemsCells`). The recycler scrolls, reuses its cells and tells
/// TalkBack; StateUI builds what a cell holds and decides what a tap chooses and opens (`ItemsTap`).
/// Design: docs/design/platforms/android/items.md
@MainActor
final class AndroidItemsView: AndroidView, AndroidRefreshing, AndroidPageScroller {
    let cells: ItemsCells

    private var layout = ItemsLayout.list()
    private var placement: AndroidItemsPlacement?
    private var choice: Choice?

    /// Every cell the recycler asked for: its pool keeps each one, so each is the list's for as long as it stands.
    private var made: [AndroidItemCell] = []

    /// Whether the list left the tree: what the recycler still says is heard by nobody.
    private var released = false

    /// Whether the motion of a change or of a scroll the tree asks for is left out.
    private let reducesMotion: () -> Bool

    var onRefreshPulled: (() -> Bool)?

    /// The swipe to refresh the recycler stands in, from the first time its parent holds it.
    private lazy var pull: AndroidRefresh = {
        let pull = AndroidRefresh(number: number)
        Java.call(pull.layout.reference, JavaAPI.addView, .object(reference), .int(-1), .int(-1))
        return pull
    }()

    var refresh: AndroidRefresh? { pull }

    /// The swipe to refresh, which its parent holds and places.
    override var outermost: jobject { pull.layout.reference }

    /// What the cells show chosen, how many the user may choose, and whether a tap does anything.
    private struct Choice: Equatable {
        var chosen: [String]
        var mode: SelectionMode
        var tappable: Bool
    }

    init(cells: ItemsCells, reducesMotion: @escaping () -> Bool) {
        self.cells = cells
        self.reducesMotion = reducesMotion
        super.init { number in
            Java.new(JavaAPI.itemsView, JavaAPI.newItemsView, .object(AndroidRenderer.context), .long(number))
        }
    }

    // MARK: - What the tree says

    /// The entries, the layout, how many may be chosen and which are.
    func apply(layout: ItemsLayout, mode: SelectionMode) {
        let old = cells.identities.count
        let changes = cells.takeEntries()
        self.layout = layout
        let placement = place()
        if let changes {
            writeEntries(changes, placement: placement, animated: old > 0 && !reducesMotion())
        } else if placement != self.placement {
            writePlacement(placement)
        }
        self.placement = placement

        let choice = Choice(
            chosen: cells.selected, mode: mode,
            tappable: mode != .none || cells.element?.handler(.itemActivated) != nil)
        guard choice != self.choice else { return }
        self.choice = choice
        Java.frame {
            let chosen = Java.strings(choice.chosen)
            Java.call(reference, JavaAPI.setItemsChoice, .object(chosen), .int(choice.mode.rawValue), .bool(choice.tappable))
        }
    }

    /// Places the list at `place`: a grid's columns follow its width, told before the recycler lays its cells out in
    /// it; at its end, it stays at its end as its room changes - a bottom bar growing beside it.
    override func layout(_ place: Rect) {
        if case .grid = layout, place.width != width {
            width = place.width
            let placement = self.place()
            if placement != self.placement {
                self.placement = placement
                writePlacement(placement)
            }
        }
        let (before, was) = (standing, placedSize)
        super.layout(place)
        // The recycler lays out from its first item; its reach grows by what its room lost, an item come meanwhile
        // left to its own scroll. Design: docs/design/platforms/android/items.md#scrolling-to-an-item
        guard let was, let now = placedSize, was != now else { return }
        let reach = Point(
            x: max(0, before.reach.x + Double(was.width - now.width) / density),
            y: max(0, before.reach.y + Double(was.height - now.height) / density))
        guard let end = ScrollArithmetic.keptAtEnd(before.offset, reach: before.reach, now: reach) else { return }
        let after = standing.offset
        let along = layout.isAcross ? end.x - after.x : end.y - after.y
        Java.call(reference, JavaAPI.scrollItemsAlong, .int(pixels(along)))
    }

    /// The width the list was last given, in points.
    private var width = 0.0

    private func place() -> AndroidItemsPlacement {
        AndroidItemsPlacement(cells.entries, layout: layout, width: width, density: density)
    }

    /// The identities with their kinds, columns and room, and the changes as runs.
    private func writeEntries(_ changes: ItemsChanges, placement: AndroidItemsPlacement, animated: Bool) {
        if placement.shape != self.placement?.shape || placement.columns != self.placement?.columns {
            writePlacement(placement)
        }
        Java.frame {
            let identities = Java.strings(cells.identities)
            let runs = { (runs: [Range<Int>]) in Java.ints(runs.flatMap { [Int32($0.lowerBound), Int32($0.count)] }) }
            Java.call(
                reference, JavaAPI.setItemsEntries, .object(identities), .object(Java.ints(placement.kinds)),
                .object(Java.ints(placement.spans)), .object(Java.ints(placement.insets)),
                .object(runs(changes.removedRuns)), .object(runs(changes.insertedRuns)), .bool(animated))
        }
    }

    private func writePlacement(_ placement: AndroidItemsPlacement) {
        Java.frame {
            Java.call(
                reference, JavaAPI.setItemsPlacement, .int(placement.shape), .int(Int32(placement.columns)),
                .object(Java.ints(placement.spans)), .object(Java.ints(placement.insets)))
        }
    }

    /// The tree's entries changed: every cell shows the subtree its entry has now (`ItemsCells.childrenChanged`).
    func childrenChanged() {
        cells.childrenChanged()
    }

    /// An entry's size would change: the cell holding it is measured again.
    func remeasure(_ item: MountedElement) {
        guard let identity = cells.identity(of: item) else { return }
        (cells.holding(of: identity) as? AndroidItemCell)?.invalidateMeasurements()
    }

    // MARK: - What the recycler says

    /// A new cell, of an item or of a header or a footer; the list keeps it.
    func makeCell(item: Bool) -> AndroidItemCell {
        let cell = AndroidItemCell(item: item)
        cell.list = self
        made.append(cell)
        return cell
    }

    /// The recycler bound `cell` to the entry of `identity`.
    func held(_ identity: String, in cell: AndroidItemCell) {
        guard !released else { return }
        cell.across = layout.isAcross
        cells.hold(identity, in: cell)
    }

    /// `cell` came on screen showing the entry of `identity`: the recycler shows a cell it kept aside again without
    /// binding it.
    func shown(_ identity: String, in cell: AndroidItemCell) {
        guard !released else { return }
        cells.show(identity, in: cell)
    }

    /// The recycler let `cell` go into its pool.
    func letGo(_ cell: AndroidItemCell) {
        guard !released else { return }
        cells.endShowing(in: cell)
    }

    /// The items in view, told once a scroll or a layout is over: a bottom bar over the list follows them.
    func showing(_ identities: [String]) {
        guard !released else { return }
        cells.showing(identities)
        standingChanged?()
    }

    // MARK: - A page's scroller

    /// What the list keeps clear of the bars over it, in points: the recycler's own padding, its items drawn through.
    private var kept = Clearance.none

    /// Keeps `clearance` clear: its first and last items scroll out from under the bars.
    /// Design: docs/design/platforms/android/items.md#scrolling-to-an-item
    func keepClear(_ clearance: Clearance) {
        guard clearance != kept else { return }
        kept = clearance
        Java.call(reference, JavaAPI.setClipToPadding, .bool(false))
        Java.call(
            reference, JavaAPI.setPadding, .int(pixels(clearance.left)), .int(pixels(clearance.top)),
            .int(pixels(clearance.right)), .int(pixels(clearance.bottom)))
    }

    var standingChanged: (() -> Void)?

    var standing: (offset: Point, reach: Point) {
        let along = Double(Java.callInt(reference, JavaAPI.itemsScrolled)) / density
        let farthest = Double(Java.callInt(reference, JavaAPI.itemsReach)) / density
        return layout.isAcross ? (Point(x: along, y: 0), Point(x: farthest, y: 0))
            : (Point(x: 0, y: along), Point(x: 0, y: farthest))
    }

    /// The user tapped the item of `identity`.
    func tapped(_ identity: String) {
        guard !released else { return }
        cells.userTapped(identity)
    }

    /// How far the recycler moves an item from `start` to `end`, in the room from `boxStart` to `boxEnd`, to stand
    /// where `anchor` says - in pixels, the item's way.
    func distance(anchor: Int32, start: Int32, end: Int32, boxStart: Int32, boxEnd: Int32) -> Int32 {
        guard let anchor = ScrollAnchor(rawValue: anchor),
              let place = anchor.place(
                of: Double(start), length: Double(end - start), in: Double(boxEnd - boxStart), at: Double(boxStart))
        else { return 0 }
        return Int32((Double(boxStart) - place).rounded())
    }

    // MARK: - Acts

    /// Scrolls until the item of `identity` stands where `anchor` says.
    func scroll(to identity: String, anchor: ScrollAnchor) {
        Java.frame {
            Java.call(
                reference, JavaAPI.scrollToItem, .object(Java.string(identity)), .int(anchor.rawValue),
                .bool(ItemsScrollTarget.glides(reducingMotion: reducesMotion())))
        }
    }

    /// The list left: the recycler lets its cells go, and they leave with it.
    override func detach() {
        super.detach()
        released = true
        Java.call(reference, JavaAPI.releaseItems)
        made.removeAll()
    }

    // MARK: - For the tests

    /// The items the cells show chosen, in the order they show.
    var selectedForTesting: [String] {
        Java.frame { Java.texts(Java.callObject(reference, JavaAPI.itemsChosen)) }
    }

    /// How many items the cells let the user choose.
    var modeForTesting: SelectionMode {
        SelectionMode(rawValue: Java.callInt(reference, JavaAPI.itemsMode)) ?? .none
    }

    /// The cell showing the entry of `identity`, where one does.
    func cellForTesting(_ identity: String) -> AndroidItemCell? {
        guard let cell = cells.holding(of: identity) as? AndroidItemCell, cell.identity == identity else { return nil }
        return cell
    }

    /// Scrolls to `target` along the list, as far as it goes.
    func scrollForTesting(to target: Point) {
        let along = layout.isAcross ? target.x : target.y
        let now = Java.callInt(reference, JavaAPI.itemsScrolled)
        Java.call(reference, JavaAPI.scrollItemsAlong, .int(pixels(along) - now))
    }
}
