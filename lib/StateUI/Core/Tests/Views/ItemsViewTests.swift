// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The items of an ItemsView as the core sends them: every identity in order,
// and only the entries a host holds in its cells built - each on its own.

import XCTest

@_spi(Host) @testable import StateUI

/// What a handler heard, in order - a class, so a closure can append to it.
private final class Received<Value> {
    var values: [Value] = []
}

/// How many times each item was built - a class, so the closure that counts
/// into it is not walked for state.
private final class Built {
    var counts: [Int: Int] = [:]
}

final class ItemsViewTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// The ItemsView element in a patch, however deep it sits.
    private func list(in patch: HostPatch) throws -> HostPatch {
        try XCTUnwrap(patch.subtree.first { $0.type == .itemsView }, "no ItemsView in the patch")
    }

    /// What a host says it holds in its cells.
    private func hold(_ identities: [String], in renders: Renders, list: HostPatch) throws -> HostPatch {
        let handler = try XCTUnwrap(list.events?[.realizedChanged], "the list hears no realizedChanged")
        renders.fire(handler, with: [.strings(identities)])
        return renders.revisit(changed: Renderer.shared.pendingChanges)
    }

    /// Every identity crosses in order - the header first - and no item is built
    /// before a host holds it.
    func testTheIdentitiesCrossInOrderAndNothingIsBuiltUnasked() throws {
        let built = Built()
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<1_000) { number in
            built.counts[number, default: 0] += 1
            return Text("\(number)")
        }
        .header(Text("Numbers")).node))

        let entries = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertEqual(entries.header, "\u{1E}header")
        XCTAssertEqual(entries.sections.count, 1)
        XCTAssertEqual(entries.sections[0].items.count, 1_000)
        XCTAssertEqual(entries.sections[0].items.prefix(3), ["0", "1", "2"])
        XCTAssertEqual(list.children.count, 0, "no entry is built before a host holds it")
        XCTAssertEqual(built.counts, [:])
    }

    /// An entry a host holds is built as a child of its own, keyed by its
    /// identity; one it lets go leaves.
    func testAnEntryHeldIsAChildOfItsOwnAndLeavesWhenLetGo() throws {
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<1_000) { Text("\($0)") }.node))

        let held = try self.list(in: hold(["4", "3"], in: renders, list: list))
        XCTAssertEqual(held.children.map(\.id), [.manual("3"), .manual("4")], "in the order they show")
        XCTAssertEqual(held.child("3")?.props[.text], .string("3"))

        let letGo = try self.list(in: hold(["4"], in: renders, list: list))
        XCTAssertEqual(letGo.arrangement, [.manual("4")], "letting an entry go arranges the children again")
    }

    /// While only the cells move, an entry already built is carried whole; the
    /// one asked for is the one built.
    func testAnEntryBuiltIsCarriedWhileOnlyTheCellsMove() throws {
        let built = Built()
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<100) { number in
            built.counts[number, default: 0] += 1
            return Text("\(number)")
        }.node))

        _ = try hold(["3"], in: renders, list: list)
        _ = try hold(["3", "4"], in: renders, list: list)
        _ = try hold(["3", "4", "5"], in: renders, list: list)

        XCTAssertEqual(built.counts, [3: 1, 4: 1, 5: 1])
    }

    /// A state one item reads builds that item alone.
    func testAStateOneItemReadsBuildsThatItemAlone() throws {
        let built = Built()
        let starred = State(wrappedValue: false)
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<100) { number in
            built.counts[number, default: 0] += 1
            return Text(number == 3 && starred.wrappedValue ? "★" : "\(number)")
        }.node))
        _ = try hold(["3", "4"], in: renders, list: list)

        starred.wrappedValue = true
        let patch = try self.list(in: renders.revisit(changed: Renderer.shared.pendingChanges))

        XCTAssertEqual(built.counts, [3: 2, 4: 1])
        XCTAssertEqual(patch.child("3")?.props[.text], .string("★"))
    }

    /// The parent building the list again builds every entry held again, as a
    /// `ForEach` builds its rows: a value the closure captured may have changed.
    func testTheParentBuildingTheListAgainBuildsEveryHeldEntry() throws {
        let built = Built()
        let renders = Renders()
        func tree(_ suffix: String) -> Node {
            ItemsView(0..<100) { number in
                built.counts[number, default: 0] += 1
                return Text("\(number)\(suffix)")
            }.node
        }
        let list = try list(in: renders.render(tree("")))
        _ = try hold(["3"], in: renders, list: list)

        let again = try self.list(in: renders.render(tree("!")))

        XCTAssertEqual(built.counts, [3: 2])
        XCTAssertEqual(again.child("3")?.props[.text], .string("3!"))
    }

    /// One chosen at a time: the binding crosses as identities, and the user's
    /// choice comes back as the item's own id.
    func testOneChoiceCrossesAsItsIdentityAndComesBackAsItsId() throws {
        let chosen = State<Int?>(wrappedValue: 5)
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<10) { Text("\($0)") }
            .selection(chosen.projectedValue).node))

        XCTAssertEqual(list.props[.selectionMode], SelectionMode.single.propValue)
        XCTAssertEqual(list.props[.selectedItems], .strings(["5"]))

        renders.fire(try XCTUnwrap(list.events?[.selectedItemsChanged]), with: [.strings(["7"])])
        XCTAssertEqual(chosen.wrappedValue, 7)

        renders.fire(try XCTUnwrap(list.events?[.selectedItemsChanged]), with: [.strings([])])
        XCTAssertNil(chosen.wrappedValue, "letting the item go clears the choice")
    }

    /// As many chosen as the user likes, in the order they show.
    func testManyChoicesCrossInTheOrderTheyShow() throws {
        let chosen = State<Set<Int>>(wrappedValue: [8, 2])
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<10) { Text("\($0)") }
            .selection(chosen.projectedValue).node))

        XCTAssertEqual(list.props[.selectionMode], SelectionMode.multiple.propValue)
        XCTAssertEqual(list.props[.selectedItems], .strings(["2", "8"]))

        renders.fire(try XCTUnwrap(list.events?[.selectedItemsChanged]), with: [.strings(["1", "2", "8"])])
        XCTAssertEqual(chosen.wrappedValue, [1, 2, 8])
    }

    /// An item the user opens is handed over as its id; the end reached is heard.
    func testAnItemOpenedNamesItsIdAndTheEndIsHeard() throws {
        let opened = Received<Int>()
        let ends = Received<Bool>()
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<10) { Text("\($0)") }
            .onItemActivated { opened.values.append($0) }
            .onEndReached(within: 3) { ends.values.append(true) }.node))

        XCTAssertEqual(list.props[.endReachedWithin], .number(3))
        renders.fire(try XCTUnwrap(list.events?[.itemActivated]), with: [.string("6")])
        renders.fire(try XCTUnwrap(list.events?[.endReached]))

        XCTAssertEqual(opened.values, [6])
        XCTAssertEqual(ends.values, [true])
    }

    /// Groups name their items apart - two groups may hold equal items - and
    /// each header and footer is an entry of its own.
    func testGroupsNameTheirItemsApart() throws {
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(groups: [
            ItemsGroup(["Apple", "Pear"]) { Text($0) }.id("Fruit").header(Text("Fruit")),
            ItemsGroup(["Apple"]) { Text($0) }.id("Cider").footer(Text("1 item")),
        ]).node))

        let entries = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertEqual(entries.sections.map(\.header), ["Fruit\u{1E}header", nil])
        XCTAssertEqual(entries.sections.map(\.footer), [nil, "Cider\u{1E}footer"])
        XCTAssertEqual(entries.sections.map(\.items), [
            ["Fruit\u{1F}Apple", "Fruit\u{1F}Pear"], ["Cider\u{1F}Apple"],
        ])

        let held = try self.list(in: hold(["Fruit\u{1E}header", "Cider\u{1F}Apple"], in: renders, list: list))
        XCTAssertEqual(held.child("Fruit\u{1E}header")?.props[.text], .string("Fruit"))
        XCTAssertEqual(held.child("Cider\u{1F}Apple")?.props[.text], .string("Apple"))
    }

    /// Two items that describe alike are told apart, as two repeated `.id()`s are.
    func testTwoItemsThatDescribeAlikeAreToldApart() throws {
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(["a", "b", "a"], id: \.self) { Text($0) }.node))

        let entries = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertEqual(entries.sections[0].items, ["a", "b", "a\u{0}1"])
    }

    /// With no items the list is its empty view; a header alone is no item.
    func testAnEmptyListIsItsEmptyView() throws {
        let renders = Renders()
        let patch = renders.render(ItemsView([Int]()) { Text("\($0)") }
            .header(Text("Numbers"))
            .emptyView(Text("Nothing yet")).node)

        XCTAssertNil(patch.subtree.first { $0.type == .itemsView })
        XCTAssertEqual(patch.subtree.first { $0.type == .text }?.props[.text], .string("Nothing yet"))
    }

    /// The entries round-trip through what crosses.
    func testTheEntriesCrossAndComeBackWhole() {
        let entries = ItemsEntries(header: "h", footer: nil, sections: [
            ItemsEntries.Section(header: nil, footer: "f", items: ["1", "2"]),
        ])
        XCTAssertEqual(ItemsEntries(propValue: entries.propValue), entries)
        XCTAssertEqual(entries.identities, ["h", "1", "2", "f"])
        XCTAssertNil(ItemsEntries(propValue: .string("nothing like it")))
    }

    /// Each layout crosses as its kind and numbers, and comes back.
    func testALayoutCrossesAndComesBack() {
        for layout: ItemsLayout in [.list(), .list(spacing: 4), .row(spacing: 8), .grid(minimumItemWidth: 120, spacing: 6)] {
            XCTAssertEqual(ItemsLayout(propValue: layout.propValue), layout)
        }
    }
}
