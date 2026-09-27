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
private struct ListPage: ContentView {
    @State private var chosen: Int?

    var content: any View {
        ItemsView(0..<100) { Label("\($0)") }
            .selection($chosen)
            .onItemActivated { Heard.opened.append($0) }
            .onEndReached(within: 5) { Heard.ends += 1 }
            .onChanged(chosen) { Heard.chosen.append(chosen) }
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
        XCTAssertEqual(cells.element.children.count, 0)
        XCTAssertNil(cells.takeEntries(), "the same entries change nothing")
    }

    /// A cell asking for an entry finds its subtree mounted at once; one let go leaves.
    func testAnEntryHeldIsMountedAtOnceAndLeavesWhenLetGo() throws {
        let item = try XCTUnwrap(cells.realize("42"), "built while the cell waits")
        XCTAssertEqual(item.type, .label)
        XCTAssertEqual(item.value(.text), .string("42"))
        XCTAssertTrue(cells.realize("42") === item, "held already, the same subtree")

        cells.release("42")
        XCTAssertNil(cells.item("42"))
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

    /// The end is told as the last item in view comes within five of the last, once.
    func testTheEndIsToldOnce() {
        cells.showing(["90", "93"])
        XCTAssertEqual(Heard.ends, 0)
        cells.showing(["94", "95"])
        cells.showing(["96", "99"])
        XCTAssertEqual(Heard.ends, 1)
    }
}
