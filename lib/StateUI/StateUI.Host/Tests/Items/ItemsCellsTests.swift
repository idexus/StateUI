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
    var scene: any Scene { ListWindow() }
}

private struct ListWindow: Window {
    var page: any Page { ListPage() }
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
        stateUIUseApp(ListApplication())
        runtime = HostRuntime.still()
        runtime.core.connectScene()
        runtime.pump.turn()
        let list = try XCTUnwrap(runtime.tree.root?.first(type: .itemsView))
        cells = ItemsCells(list, in: runtime)
        cells.takeEntries()
    }

    /// Every identity is taken in order, and nothing is built before a cell holds it.
    func testTheEntriesAreTakenAndNothingIsBuiltUnasked() {
        XCTAssertEqual(cells.identities.count, 100)
        XCTAssertEqual(cells.identities.prefix(2), ["0", "1"])
        XCTAssertEqual(cells.element?.children.count, 0)
        XCTAssertNil(cells.takeEntries(), "the same entries change nothing")
    }

    /// A cell asked for an entry shows its subtree at once, and the tree builds the entries within reach of the
    /// cells with it - eight before and after a single cell - and nothing further.
    func testAnEntryHeldIsBuiltAtOnceWithThoseWithinReach() throws {
        let cell = Cell()
        cells.hold("42", in: cell)
        let item = try XCTUnwrap(cell.shown, "built while the cell waits")
        XCTAssertEqual(item.type, .text)
        XCTAssertEqual(item.value(.text), .string("42"))
        XCTAssertNotNil(cells.item("34"))
        XCTAssertNotNil(cells.item("50"))
        XCTAssertNil(cells.item("33"), "nothing beyond reach")
        XCTAssertNil(cells.item("51"))
    }

    /// A cell asked for an entry already built takes it without a render: a scroll costs a render a reach, not one
    /// a cell.
    func testAnEntryWithinReachIsHeldWithoutARender() {
        cells.hold("0", in: Cell())
        let renders = runtime.core.tally.renders
        for identity in 1...8 { cells.hold("\(identity)", in: Cell()) }
        XCTAssertEqual(runtime.core.tally.renders, renders)
    }

    /// A cell that ended showing its entry tells the tree nothing at once; the entry leaves once the cells moved out
    /// of its reach.
    func testAnEntryLetGoLeavesOnceTheCellsMoveAway() {
        let cell = Cell()
        cells.hold("0", in: cell)
        let renders = runtime.core.tally.renders
        cells.endShowing(in: cell)
        XCTAssertEqual(runtime.core.tally.renders, renders, "a cell leaving costs no render")
        XCTAssertNil(cell.identity)
        XCTAssertNotNil(cells.item("0"), "within reach still")

        cells.hold("60", in: Cell())
        XCTAssertNil(cells.item("0"), "gone once the cells moved away")
        XCTAssertNotNil(cells.item("60"))
    }

    /// Cells far apart - a jump to another place in the list - build what is within reach of each, nothing between.
    func testCellsFarApartBuildOnlyAroundThemselves() {
        cells.hold("0", in: Cell())
        cells.hold("90", in: Cell())
        XCTAssertNotNil(cells.item("8"))
        XCTAssertNotNil(cells.item("82"))
        XCTAssertNotNil(cells.item("98"))
        XCTAssertNil(cells.item("45"))
    }

    /// A second cell asked for an entry takes it from the first, which shows nothing; the first ending showing lets
    /// nothing go - only the cell holding the entry does.
    func testOnlyTheCellHoldingAnEntryLetsItGo() {
        let (first, second) = (Cell(), Cell())
        cells.hold("5", in: first)
        cells.hold("5", in: second)
        XCTAssertNil(first.identity, "the first cell shows nothing")
        XCTAssertTrue(second.shown === cells.item("5"))

        cells.endShowing(in: first)
        XCTAssertTrue(cells.holding(of: "5") === second, "the second cell still holds it")
        cells.endShowing(in: second)
        XCTAssertNil(cells.holding(of: "5"))
    }

    /// A cell shown again after it ended showing its entry - a collection keeps recent cells aside and shows them
    /// without asking - takes its entry back.
    func testACellShownAgainTakesItsEntryBack() {
        let cell = Cell()
        cells.hold("7", in: cell)
        cells.endShowing(in: cell)
        XCTAssertNil(cell.identity)

        cells.show("7", in: cell)
        XCTAssertEqual(cell.identity, "7")
        XCTAssertNotNil(cell.shown)
        XCTAssertTrue(cell.shown === cells.item("7"))
    }

    /// After the tree's entries change, every cell shows the subtree its entry has now.
    func testEveryCellShowsItsEntrysSubtreeAfterAChange() {
        let cell = Cell()
        cells.hold("3", in: cell)
        cell.shown = nil

        let changed = cells.childrenChanged()
        XCTAssertTrue(cell.shown === cells.item("3"))
        XCTAssertEqual(changed.count, 1)
        XCTAssertTrue(cells.childrenChanged().isEmpty, "nothing more to change")
    }

    /// The user's choice reaches the page as the item's id, and a choice the page already holds is not told again.
    func testTheUsersChoiceReachesThePage() {
        cells.userChose(["7"])
        XCTAssertEqual(Heard.chosen, [7])

        ProgramWrite.perform { cells.userChose(["8"]) }
        XCTAssertEqual(Heard.chosen, [7], "what the program selects is not the user's")
    }

    /// An item opened is handed over as its id; a header or none is not.
    func testAnItemOpenedIsHandedOver() {
        cells.userActivated("12")
        cells.userActivated("no such item")
        XCTAssertEqual(Heard.opened, [12])
    }

    /// A tap on an item of a list choosing one chooses it and opens it; a tap on a header or on nothing does nothing.
    func testATapChoosesTheItemAndOpensIt() {
        cells.userTapped("4")
        cells.userTapped("no such item")
        XCTAssertEqual(Heard.chosen, [4])
        XCTAssertEqual(Heard.opened, [4])
    }

    /// The end is told as the last item in view comes within five of the last, once.
    func testTheEndIsToldOnce() {
        cells.showing(["90", "93"])
        XCTAssertEqual(Heard.ends, 0)
        cells.showing(["94", "95"])
        cells.showing(["96", "99"])
        XCTAssertEqual(Heard.ends, 1)
    }
}
