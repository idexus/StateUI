// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What the page's list heard, in order.
private enum Heard {
    nonisolated(unsafe) static var chosen: [Int?] = []
    nonisolated(unsafe) static var ends = 0
    nonisolated(unsafe) static var opened: [Int] = []
}

private struct ListApplication: Application {
    var body: some Scene { WindowGroup { ListPage() } }
}

/// A hundred numbered items, one chosen at a time, more asked for near the end.
private struct ListPage: View {
    @State private var chosen: Int?

    var body: some View {
        ItemsView(0..<100) { Text("\($0)") }
            .selection($chosen)
            .onItemActivated { Heard.opened.append($0) }
            .onEndReached(within: 5) { Heard.ends += 1 }
            .onChanged(chosen) { Heard.chosen.append(chosen) }
    }
}

/// How many items the shrinking list shows, which a test lowers.
private enum Shrinking {
    nonisolated(unsafe) static var count = 10
}

private struct ShrinkingApplication: Application {
    var body: some Scene { WindowGroup { ShrinkingPage() } }
}

private struct ShrinkingPage: View {
    var body: some View { ItemsView(0..<Shrinking.count) { Text("\($0)") } }
}

/// The items a changing list shows and the header it has, which a test replaces, and how often its end was told.
private enum Changing {
    nonisolated(unsafe) static var items = Array(0..<10)
    nonisolated(unsafe) static var header: String?
    nonisolated(unsafe) static var ends = 0
}

private struct ChangingApplication: Application {
    var body: some Scene { WindowGroup { ChangingPage() } }
}

private struct ChangingPage: View {
    var body: some View {
        var list = ItemsView(Changing.items) { Text("\($0)") }
        if let header = Changing.header { list = list.header { Text(header) } }
        return list.onEndReached(within: 0) { Changing.ends += 1 }
    }
}

/// A native cell as the host layer holds it.
@MainActor
private final class Cell: ItemsHolding {
    var identity: String?
    var shown: MountedElement?

    func hold(_ identity: String, _ item: MountedElement?) {
        self.identity = identity
        shown = item
    }

    func letGo() {
        identity = nil
        shown = nil
    }
}

/// A list whose mail item offers its actions in a context menu, and whose other item offers none.
private struct ActionsApplication: Application {
    var body: some Scene { WindowGroup { ActionsPage() } }
}

private struct ActionsPage: View {
    var body: some View {
        ItemsView(["mail", "plain"]) { item in
            if item == "mail" {
                Text(item).contextMenu {
                    MenuItem("Archive").onClicked {}
                    MenuSeparator()
                    Menu("Move") { MenuItem("Inbox").onClicked {} }
                    MenuItem("Flag").isEnabled(false).onClicked {}
                    MenuItem("Delete").role(.destructive).onClicked {}
                }
            } else {
                Text(item)
            }
        }
    }
}

/// A platform's collection over the real core: what it holds is built at once, what it lets go leaves, and what the
/// user does reaches the page in the list's order.
@MainActor
final class ItemsCellsTests: XCTestCase {
    private var runtime: HostRuntime!
    private var cells: ItemsCells!

    override func setUp() async throws {
        Heard.chosen = []
        Heard.ends = 0
        Heard.opened = []
        ListApplication.register()
        runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let list = try XCTUnwrap(runtime.tree.root?.first(type: .itemsView))
        cells = ItemsCells(list, in: runtime)
        cells.takeEntries()
    }

    private func token(_ position: Int, in cells: ItemsCells, file: StaticString = #filePath, line: UInt = #line) -> String {
        let items = cells.entries.sections.flatMap(\.items)
        guard items.indices.contains(position) else {
            XCTFail("no emitted item token at position \(position)", file: file, line: line)
            return "<missing item \(position)>"
        }
        return items[position]
    }

    /// A cell shows an entry anew where it is another than the one it shows, or where its view and the entry
    /// disagree on whether there is a subtree to show; the same entry already in its view is left alone.
    func testACellShowsAnEntryAnewOnlyWhereItChanges() throws {
        let item = try XCTUnwrap(cells.element)
        let cell = Cell()
        XCTAssertTrue(cell.showsAnew(item, viewShowing: false), "an entry where none is shown")
        cell.hold("0", item)
        XCTAssertFalse(cell.showsAnew(item, viewShowing: true), "the same entry, shown")
        XCTAssertTrue(cell.showsAnew(item, viewShowing: false), "the same entry, its view emptied")
        XCTAssertTrue(cell.showsAnew(nil, viewShowing: true), "nothing where a subtree is shown")
        cell.letGo()
        XCTAssertFalse(cell.showsAnew(nil, viewShowing: false), "nothing, and nothing shown")
    }

    /// A cell keeps, before its entry is measured, the room of a row down a list and of an item across a row - one
    /// estimate for every host, wide enough across that a row asks for about as many entries as it shows.
    func testACellKeepsOneEstimateBeforeItsEntryIsMeasured() {
        XCTAssertEqual(ItemsCells.estimatedExtent(across: false), 44)
        XCTAssertEqual(ItemsCells.estimatedExtent(across: true), 100)
    }

    /// A size changing inside an entry is measured again from there up to the entry, whose cell measures it - the
    /// list's own size never follows its items; outside a list every layout up to the root measures again.
    func testMeasuringAgainStopsAtTheEntryACellMeasures() throws {
        let cell = Cell()
        cells.hold(token(42, in: cells), in: cell)
        let entry = try XCTUnwrap(cell.shown)

        let inside = entry.measuredUpward()
        XCTAssertTrue(inside.layouts.isEmpty, "the entry is its cell's to measure")
        XCTAssertTrue(inside.entry === entry)

        let list = try XCTUnwrap(cells.element)
        let outside = list.measuredUpward()
        XCTAssertNil(outside.entry)
        XCTAssertTrue(outside.layouts.first === list)
        XCTAssertTrue(outside.layouts.last === runtime.tree.root, "up to the root")
    }

    /// A scroll to an item glides there, unless the user asked for less motion.
    func testAScrollToAnItemGlidesUnlessTheUserAsksForLessMotion() {
        XCTAssertTrue(ItemsScrollTarget.glides(reducingMotion: false))
        XCTAssertFalse(ItemsScrollTarget.glides(reducingMotion: true))
    }

    /// Every identity is taken in order, and nothing is built before a cell holds it.
    func testTheEntriesAreTakenAndNothingIsBuiltUnasked() {
        XCTAssertEqual(cells.identities.count, 100)
        XCTAssertEqual(Set(cells.identities).count, 100)
        XCTAssertEqual(cells.identities, cells.entries.identities, "in the described order")
        XCTAssertEqual(cells.element?.children.count, 0)
        XCTAssertNil(cells.takeEntries(), "the same entries change nothing")
    }

    /// A cell asked for an entry shows its subtree at once, and the tree builds the entries within reach of the
    /// cells with it - eight before and after a single cell - and nothing further.
    func testAnEntryHeldIsBuiltAtOnceWithThoseWithinReach() throws {
        let cell = Cell()
        cells.hold(token(42, in: cells), in: cell)
        let item = try XCTUnwrap(cell.shown, "built while the cell waits")
        XCTAssertEqual(item.type, .text)
        XCTAssertEqual(item.value(.text), .string("42"))
        XCTAssertNotNil(cells.item(token(34, in: cells)))
        XCTAssertNotNil(cells.item(token(50, in: cells)))
        XCTAssertNil(cells.item(token(33, in: cells)), "nothing beyond reach")
        XCTAssertNil(cells.item(token(51, in: cells)))
    }

    /// A cell asked for an entry already built, half a reach from the built end, takes it without a render: a scroll
    /// costs a render a half reach, not one a cell.
    func testAnEntryWithinReachIsHeldWithoutARender() {
        cells.hold(token(0, in: cells), in: Cell())
        let renders = runtime.core.tally.renders
        for identity in 1...4 { cells.hold(token(identity, in: cells), in: Cell()) }
        XCTAssertEqual(runtime.core.tally.renders, renders)
    }

    /// A cell coming within half a reach of the entries built asks for the next ones before it finds one unbuilt:
    /// each render builds half a reach, twice as often, rather than a whole reach at once.
    func testACellHalfAReachFromTheBuiltEndBuildsTheNext() {
        cells.hold(token(0, in: cells), in: Cell())
        for identity in 1...4 { cells.hold(token(identity, in: cells), in: Cell()) }
        XCTAssertNil(cells.item(token(9, in: cells)), "a reach of eight around the first cell")
        let renders = runtime.core.tally.renders

        cells.hold(token(5, in: cells), in: Cell())

        XCTAssertEqual(runtime.core.tally.renders, renders + 1, "built already, and half a reach from the end")
        XCTAssertNotNil(cells.item(token(13, in: cells)), "a reach around every cell held")
    }

    /// Cells coming near and going away in one batch - a fast scroll seen in one frame - are told together: the ones
    /// gone let their entries go first, the tree is told once, and builds around the cells near now alone.
    func testCellsComingAndGoingTogetherTellTheTreeOnce() {
        let gone = (60..<70).map { _ in Cell() }
        for (offset, cell) in gone.enumerated() { cells.hold(token(60 + offset, in: cells), in: cell) }
        let coming = (0..<10).map { (identity: token($0, in: cells), value: $0, holding: Cell()) }
        let renders = runtime.core.tally.renders

        cells.hold(coming.map { ($0.identity, $0.holding as any ItemsHolding) }, endingShowing: gone)

        XCTAssertEqual(runtime.core.tally.renders, renders + 1, "one render for the batch")
        XCTAssertNotNil(cells.item(token(19, in: cells)), "a reach of ten after the last cell near")
        XCTAssertNil(cells.item(token(20, in: cells)))
        XCTAssertNil(cells.item(token(65, in: cells)), "nothing kept around the cells gone")
        for item in coming { XCTAssertEqual(item.holding.shown?.value(.text), .string(String(item.value))) }
        XCTAssertTrue(gone.allSatisfy { $0.identity == nil })
    }

    /// A cell that ended showing its entry tells the tree nothing at once; the entry leaves once the cells moved out
    /// of its reach.
    func testAnEntryLetGoLeavesOnceTheCellsMoveAway() {
        let cell = Cell()
        cells.hold(token(0, in: cells), in: cell)
        let renders = runtime.core.tally.renders
        cells.endShowing(in: cell)
        XCTAssertEqual(runtime.core.tally.renders, renders, "a cell leaving costs no render")
        XCTAssertNil(cell.identity)
        XCTAssertNotNil(cells.item(token(0, in: cells)), "within reach still")

        cells.hold(token(60, in: cells), in: Cell())
        XCTAssertNil(cells.item(token(0, in: cells)), "gone once the cells moved away")
        XCTAssertNotNil(cells.item(token(60, in: cells)))
    }

    /// The item the program scrolled to is stood again after every pass while a cell waits for its entry - one
    /// measured as it comes moves the items after it - once more as the last entry comes, and then let go.
    func testAnItemScrolledToStandsAgainWhileACellWaitsForItsEntry() {
        let waiting = Cell()
        cells.hold(token(79, in: cells), in: waiting)
        cells.hold(token(80, in: cells), in: Cell())
        waiting.shown = nil
        cells.scroll(to: token(80, in: cells), anchor: .start)

        XCTAssertEqual(cells.laidOut(), ItemsScrollTarget(identity: token(80, in: cells), anchor: .start), "a cell waits")
        XCTAssertEqual(cells.laidOut(), ItemsScrollTarget(identity: token(80, in: cells), anchor: .start), "and waits still")
        cells.childrenChanged()
        XCTAssertEqual(cells.laidOut(), ItemsScrollTarget(identity: token(80, in: cells), anchor: .start), "its entry came")
        XCTAssertNil(cells.laidOut(), "none waits any more")
    }

    /// The item scrolled to is held until a cell shows its own entry, though no cell waits for one: the cells near
    /// the place it was scrolled to may come after the pass.
    func testAnItemScrolledToIsHeldUntilItsOwnCellShowsIt() {
        cells.hold(token(0, in: cells), in: Cell())
        cells.scroll(to: token(90, in: cells), anchor: .start)
        XCTAssertEqual(cells.laidOut(), ItemsScrollTarget(identity: token(90, in: cells), anchor: .start), "no cell holds it yet")

        cells.hold(token(90, in: cells), in: Cell())
        XCTAssertEqual(cells.laidOut(), ItemsScrollTarget(identity: token(90, in: cells), anchor: .start), "its cell shows it")
        XCTAssertNil(cells.laidOut())
    }

    /// The user moving the list lets the item the program scrolled to go, and so does the next scroll: the last
    /// word on where the list stands is theirs.
    func testTheUsersMoveAndTheNextScrollLetTheItemScrolledToGo() {
        let waiting = Cell()
        cells.hold(token(10, in: cells), in: waiting)
        waiting.shown = nil
        cells.scroll(to: token(10, in: cells), anchor: .center)
        cells.userScrolled()
        XCTAssertNil(cells.laidOut(), "the user moved the list")

        cells.scroll(to: token(10, in: cells), anchor: .center)
        cells.scroll(to: token(20, in: cells), anchor: .end)
        XCTAssertEqual(cells.laidOut(), ItemsScrollTarget(identity: token(20, in: cells), anchor: .end), "the next scroll's")
    }

    /// The item the program scrolled to stands again as its list's room changes - a sheet laid out at the screen's
    /// size first, then at its own - stood or held, until anything else moves the list: the user, the next scroll.
    func testAnItemScrolledToStandsAgainAsItsListsRoomChanges() {
        let end = ItemsScrollTarget(identity: token(19, in: cells), anchor: .end)
        cells.hold(token(19, in: cells), in: Cell())
        cells.scroll(to: token(19, in: cells), anchor: .end)
        XCTAssertEqual(cells.roomChanged(), end, "held")
        XCTAssertEqual(cells.laidOut(), end)
        XCTAssertNil(cells.laidOut(), "let go of as its cell shows it")
        XCTAssertEqual(cells.roomChanged(), end, "stood: its room changed")
        XCTAssertEqual(cells.roomChanged(), end, "and changed again")

        cells.userScrolled()
        XCTAssertNil(cells.roomChanged(), "the user moved the list")

        cells.scroll(to: token(19, in: cells), anchor: .end)
        _ = cells.laidOut()
        cells.scroll(to: token(5, in: cells), anchor: .start)
        XCTAssertEqual(cells.roomChanged(), ItemsScrollTarget(identity: token(5, in: cells), anchor: .start), "the next scroll's")
    }

    /// The item stood is let go of as the list's entries change: an item come or gone moves what stands where.
    func testAnItemStoodIsLetGoAsTheEntriesChange() throws {
        Shrinking.count = 10
        ShrinkingApplication.register()
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let cells = ItemsCells(try XCTUnwrap(runtime.tree.root?.first(type: .itemsView)), in: runtime)
        cells.takeEntries()
        cells.hold(token(2, in: cells), in: Cell())
        cells.scroll(to: token(2, in: cells), anchor: .end)
        _ = cells.laidOut()
        XCTAssertNotNil(cells.roomChanged())

        Shrinking.count = 5
        Renderer.shared.setNeedsRender()
        runtime.pump.turn()
        cells.takeEntries()
        XCTAssertNil(cells.roomChanged())
    }

    /// Cells far apart - a jump to another place in the list - build what is within reach of each, nothing between.
    func testCellsFarApartBuildOnlyAroundThemselves() {
        cells.hold(token(0, in: cells), in: Cell())
        cells.hold(token(90, in: cells), in: Cell())
        XCTAssertNotNil(cells.item(token(8, in: cells)))
        XCTAssertNotNil(cells.item(token(82, in: cells)))
        XCTAssertNotNil(cells.item(token(98, in: cells)))
        XCTAssertNil(cells.item(token(45, in: cells)))
    }

    /// A second cell asked for an entry takes it from the first, which shows nothing; the first ending showing lets
    /// nothing go - only the cell holding the entry does.
    /// An entry the list no longer has is let go of by the cell holding it: the cells keep nothing of what went.
    func testACellOfAnEntryThatWentLetsItGo() throws {
        Shrinking.count = 10
        ShrinkingApplication.register()
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let cells = ItemsCells(try XCTUnwrap(runtime.tree.root?.first(type: .itemsView)), in: runtime)
        cells.takeEntries()
        let cell = Cell()
        let removed = token(7, in: cells)
        cells.hold(removed, in: cell)

        Shrinking.count = 5
        Renderer.shared.setNeedsRender()
        runtime.pump.turn()
        cells.takeEntries()

        XCTAssertNil(cells.holding(of: removed))
        XCTAssertNil(cell.identity, "the cell let the entry go")
    }

    /// An item's actions as a swipe shows them are its context menu's items the user can choose, in order - a line,
    /// a submenu and an item turned off left out, a destructive one marked; an item with no menu offers none.
    func testAnItemsActionsAreTheItemsOfItsContextMenuASwipeShows() throws {
        ActionsApplication.register()
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let cells = ItemsCells(try XCTUnwrap(runtime.tree.root?.first(type: .itemsView)), in: runtime)
        cells.takeEntries()
        cells.hold("mail", in: Cell())
        cells.hold("plain", in: Cell())

        let actions = cells.actions(of: "mail")
        XCTAssertEqual(actions.map(\.title), ["Archive", "Delete"])
        XCTAssertEqual(actions.map(\.isDestructive), [false, true])
        XCTAssertEqual(cells.actions(of: "plain").count, 0)
    }

    func testOnlyTheCellHoldingAnEntryLetsItGo() {
        let (first, second) = (Cell(), Cell())
        cells.hold(token(5, in: cells), in: first)
        cells.hold(token(5, in: cells), in: second)
        XCTAssertNil(first.identity, "the first cell shows nothing")
        XCTAssertTrue(second.shown === cells.item(token(5, in: cells)))

        cells.endShowing(in: first)
        XCTAssertTrue(cells.holding(of: token(5, in: cells)) === second, "the second cell still holds it")
        cells.endShowing(in: second)
        XCTAssertNil(cells.holding(of: token(5, in: cells)))
    }

    /// A cell shown again after it ended showing its entry - a collection keeps recent cells aside and shows them
    /// without asking - takes its entry back.
    func testACellShownAgainTakesItsEntryBack() {
        let cell = Cell()
        cells.hold(token(7, in: cells), in: cell)
        cells.endShowing(in: cell)
        XCTAssertNil(cell.identity)

        cells.show(token(7, in: cells), in: cell)
        XCTAssertEqual(cell.identity, token(7, in: cells))
        XCTAssertNotNil(cell.shown)
        XCTAssertTrue(cell.shown === cells.item(token(7, in: cells)))
    }

    /// After the tree's entries change, every cell shows the subtree its entry has now.
    func testEveryCellShowsItsEntrysSubtreeAfterAChange() {
        let cell = Cell()
        cells.hold(token(3, in: cells), in: cell)
        cell.shown = nil

        let changed = cells.childrenChanged()
        XCTAssertTrue(cell.shown === cells.item(token(3, in: cells)))
        XCTAssertEqual(changed.count, 1)
        XCTAssertTrue(cells.childrenChanged().isEmpty, "nothing more to change")
    }

    /// The user's choice reaches the page as the item's id; what the program selects is not told.
    func testTheUsersChoiceReachesThePage() {
        cells.userChose([token(7, in: cells)])
        XCTAssertEqual(Heard.chosen, [7])

        ProgramWrite.perform { cells.userChose([token(8, in: cells)]) }
        XCTAssertEqual(Heard.chosen, [7], "what the program selects is not the user's")
    }

    /// An item opened is handed over as its id; a header or none is not.
    func testAnItemOpenedIsHandedOver() {
        cells.userActivated(token(12, in: cells))
        cells.userActivated("no such item")
        XCTAssertEqual(Heard.opened, [12])
    }

    /// A tap on an item of a list choosing one chooses it and opens it; a tap on a header or on nothing does nothing.
    func testATapChoosesTheItemAndOpensIt() {
        cells.userTapped(token(4, in: cells))
        cells.userTapped("no such item")
        XCTAssertEqual(Heard.chosen, [4])
        XCTAssertEqual(Heard.opened, [4])
    }

    /// The end is told as the last item in view comes within five of the last, once.
    func testTheEndIsToldOnce() {
        cells.showing([token(90, in: cells), token(93, in: cells)])
        XCTAssertEqual(Heard.ends, 0)
        cells.showing([token(94, in: cells), token(95, in: cells)])
        cells.showing([token(96, in: cells), token(99, in: cells)])
        XCTAssertEqual(Heard.ends, 1)
    }

    /// The end is told again once items came or went - the items replaced by as many others, one more added - and
    /// not as the same items stand in another order or a header comes, the view staying at the end throughout.
    func testTheEndIsToldAgainOnceItemsCameOrWent() throws {
        Changing.items = Array(0..<10)
        Changing.header = nil
        Changing.ends = 0
        ChangingApplication.register()
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let cells = ItemsCells(try XCTUnwrap(runtime.tree.root?.first(type: .itemsView)), in: runtime)
        cells.takeEntries()
        func replace(_ items: [Int], header: String? = nil) {
            Changing.items = items
            Changing.header = header
            Renderer.shared.setNeedsRender()
            runtime.pump.turn()
            cells.takeEntries()
        }

        cells.showing([token(9, in: cells)])
        XCTAssertEqual(Changing.ends, 1)
        replace(Array((0..<10).reversed()))
        cells.showing([token(9, in: cells)])
        XCTAssertEqual(Changing.ends, 1, "the same items in another order")
        replace(Array(0..<10), header: "Header")
        cells.showing([token(9, in: cells)])
        XCTAssertEqual(Changing.ends, 1, "a header is no item")
        replace(Array(10..<20), header: "Header")
        cells.showing([token(9, in: cells)])
        XCTAssertEqual(Changing.ends, 2, "others came, as many as went")
        replace(Array(10..<21), header: "Header")
        cells.showing([token(10, in: cells)])
        XCTAssertEqual(Changing.ends, 3, "one more came")
    }

    /// A list's view moving moves its items in the window though nothing is laid out: whoever reads a frame says it
    /// on the display's next frame, whatever the list hears.
    func testAListsViewMovingSaysWhereItsItemsStand() throws {
        PlainListApplication.register()
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let cells = ItemsCells(try XCTUnwrap(runtime.tree.root?.first(type: .itemsView)), in: runtime)
        cells.takeEntries()
        let reader = Reader()
        runtime.frames.follow(reader, of: try XCTUnwrap(runtime.tree.root?.first(type: .itemsView)), reads: true)
        runtime.frames.commit(now: 16)
        reader.said = 0

        cells.showing([token(3, in: cells), token(4, in: cells), token(5, in: cells)])
        runtime.frames.commit(now: 32)

        XCTAssertEqual(reader.said, 1)
    }

    /// The band behind a chosen item is the accent's hue at a fifth of its strength, packed as a toolkit takes it.
    func testAChosenItemsBandIsTheAccentAtAFifth() {
        XCTAssertEqual(ChosenBand.opacity, 0.2)
        XCTAssertEqual(ChosenBand.argb(over: 0xFF0A_84FF), 0x330A_84FF)
        XCTAssertEqual(ChosenBand.argb(over: 0x8012_3456), 0x3312_3456, "the accent's own alpha gives way")
    }
}

private struct PlainListApplication: Application {
    var body: some Scene { WindowGroup { ItemsView(0..<100) { Text("\($0)") } } }
}

/// An element whose frame the tree reads, counting how often it said where it stands.
@MainActor
private final class Reader: FrameReporter {
    var said = 0

    func reportFrame() {
        said += 1
    }
}
