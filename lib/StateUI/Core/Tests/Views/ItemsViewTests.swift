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

/// A list of the numbers a state holds, built again as they change.
private struct NumbersList: View {
    let numbers: State<[Int]>

    var body: some View {
        ItemsView(numbers.wrappedValue) { Text("\($0)") }
    }
}

/// How many times each item was built - a class, so the closure that counts
/// into it is not walked for state.
private final class Built {
    var counts: [Int: Int] = [:]
}

@MainActor
final class ItemsViewTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// The ItemsView element in a patch, however deep it sits.
    private func list(in patch: HostPatch) throws -> HostPatch {
        try XCTUnwrap(patch.subtree.first { $0.type == .itemsView }, "no ItemsView in the patch")
    }

    private func itemIdentities(in list: HostPatch) throws -> [String] {
        try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:))).sections.flatMap(\.items)
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
        .header { Text("Numbers") }.node))

        let entries = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertEqual(entries.header, "\u{1E}header")
        XCTAssertEqual(entries.sections.count, 1)
        XCTAssertEqual(entries.sections[0].items.count, 1_000)
        XCTAssertEqual(Set(entries.sections[0].items).count, 1_000)
        XCTAssertEqual(list.children.count, 0, "no entry is built before a host holds it")
        XCTAssertEqual(built.counts, [:])
        let shown = try self.list(in: hold(Array(entries.sections[0].items.prefix(3)), in: renders, list: list))
        XCTAssertEqual(shown.children.map { $0.props[.text]?.string }, ["0", "1", "2"])
    }

    /// An entry a host holds is built as a child of its own, keyed by its
    /// identity; one it lets go leaves.
    func testAnEntryHeldIsAChildOfItsOwnAndLeavesWhenLetGo() throws {
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<1_000) { Text("\($0)") }.node))
        let ids = try itemIdentities(in: list)

        let held = try self.list(in: hold([ids[4], ids[3]], in: renders, list: list))
        XCTAssertEqual(held.children.map(\.id), [.manual(ids[3]), .manual(ids[4])], "in the order they show")
        XCTAssertEqual(held.child(ids[3])?.props[.text], .string("3"))

        let letGo = try self.list(in: hold([ids[4]], in: renders, list: list))
        XCTAssertEqual(letGo.arrangement, [.manual(ids[4])], "letting an entry go arranges the children again")
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
        let ids = try itemIdentities(in: list)

        _ = try hold([ids[3]], in: renders, list: list)
        _ = try hold([ids[3], ids[4]], in: renders, list: list)
        _ = try hold([ids[3], ids[4], ids[5]], in: renders, list: list)

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
        let ids = try itemIdentities(in: list)
        _ = try hold([ids[3], ids[4]], in: renders, list: list)

        starred.wrappedValue = true
        let patch = try self.list(in: renders.revisit(changed: Renderer.shared.pendingChanges))

        XCTAssertEqual(built.counts, [3: 2, 4: 1])
        XCTAssertEqual(patch.child(ids[3])?.props[.text], .string("★"))
    }

    /// A change that moves the entries builds, in the same render, the entry it brings to where a held one stood: the
    /// collection laying the change out finds it built, and measures it before it moves a row.
    func testAChangeBuildsTheEntryItBringsWhereAHeldOneStood() throws {
        let numbers = State(wrappedValue: Array(0..<100))
        let renders = Renders()
        let list = try list(in: renders.render(NumbersList(numbers: numbers).node))
        let ids = try itemIdentities(in: list)
        _ = try hold([ids[0], ids[1], ids[2]], in: renders, list: list)

        numbers.wrappedValue = [99] + Array(0..<99)
        let moved = try self.list(in: renders.revisit(changed: Renderer.shared.pendingChanges))

        XCTAssertEqual(moved.arrangement, [.manual(ids[99]), .manual(ids[0]), .manual(ids[1]), .manual(ids[2])])
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
        let ids = try itemIdentities(in: list)
        _ = try hold([ids[3]], in: renders, list: list)

        let again = try self.list(in: renders.render(tree("!")))

        XCTAssertEqual(built.counts, [3: 2])
        XCTAssertEqual(again.child(ids[3])?.props[.text], .string("3!"))
    }

    /// One chosen at a time: the binding crosses as identities, and the user's
    /// choice comes back as the item's own id.
    func testOneChoiceCrossesAsItsIdentityAndComesBackAsItsId() throws {
        let chosen = State<Int?>(wrappedValue: 5)
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<10) { Text("\($0)") }
            .selection(chosen.projectedValue).node))
        let ids = try itemIdentities(in: list)

        XCTAssertEqual(list.props[.selectionMode], SelectionMode.single.propValue)
        XCTAssertEqual(list.props[.selectedItems], .strings([ids[5]]))

        renders.fire(try XCTUnwrap(list.events?[.selectedItemsChanged]), with: [.strings([ids[7]])])
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
        let ids = try itemIdentities(in: list)

        XCTAssertEqual(list.props[.selectionMode], SelectionMode.multiple.propValue)
        XCTAssertEqual(list.props[.selectedItems], .strings([ids[2], ids[8]]))

        renders.fire(try XCTUnwrap(list.events?[.selectedItemsChanged]), with: [.strings([ids[1], ids[2], ids[8]])])
        XCTAssertEqual(chosen.wrappedValue, [1, 2, 8])
    }

    /// A list given its selection as a state reports the choice too, after writing it.
    func testAChoiceGivenAsAStateIsReportedAfterItIsWritten() throws {
        let chosen = State<Int?>(wrappedValue: nil)
        let seen = Received<Int?>()
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<10) { Text("\($0)") }
            .selection(chosen.projectedValue)
            .onSelectionChanged { seen.values.append(chosen.wrappedValue) }.node))
        let ids = try itemIdentities(in: list)

        renders.fire(try XCTUnwrap(list.events?[.selectedItemsChanged]), with: [.strings([ids[3]])])
        XCTAssertEqual(seen.values, [3])
    }

    /// An item the user opens is handed over as its id; the end reached is heard.
    func testAnItemOpenedNamesItsIdAndTheEndIsHeard() throws {
        let opened = Received<Int>()
        let ends = Received<Bool>()
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<10) { Text("\($0)") }
            .onItemActivated { opened.values.append($0) }
            .onEndReached(within: 3) { ends.values.append(true) }.node))
        let ids = try itemIdentities(in: list)

        XCTAssertEqual(list.props[.endReachedWithin], .number(3))
        renders.fire(try XCTUnwrap(list.events?[.itemActivated]), with: [.string(ids[6])])
        renders.fire(try XCTUnwrap(list.events?[.endReached]))

        XCTAssertEqual(opened.values, [6])
        XCTAssertEqual(ends.values, [true])
    }

    /// Every handler of an event runs, in the order written; the end is heard within the farthest distance written.
    func testEveryHandlerOfAnEventRunsInWritingOrder() throws {
        let heard = Received<String>()
        let chosen = State<Int?>(wrappedValue: nil)
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(0..<10) { Text("\($0)") }
            .selection(chosen.projectedValue)
            .onSelectionChanged { heard.values.append("chose \(chosen.wrappedValue ?? -1) first") }
            .onSelectionChanged { heard.values.append("chose \(chosen.wrappedValue ?? -1) second") }
            .onItemActivated { heard.values.append("opened \($0) first") }
            .onItemActivated { heard.values.append("opened \($0) second") }
            .onEndReached(within: 5) { heard.values.append("end first") }
            .onEndReached(within: 2) { heard.values.append("end second") }.node))
        let ids = try itemIdentities(in: list)

        XCTAssertEqual(list.props[.endReachedWithin], .number(5), "the farthest distance written")
        renders.fire(try XCTUnwrap(list.events?[.selectedItemsChanged]), with: [.strings([ids[3]])])
        renders.fire(try XCTUnwrap(list.events?[.itemActivated]), with: [.string(ids[6])])
        renders.fire(try XCTUnwrap(list.events?[.endReached]))

        XCTAssertEqual(heard.values, [
            "chose 3 first", "chose 3 second", "opened 6 first", "opened 6 second", "end first", "end second",
        ])
    }

    /// An item is known by its value in the whole list, whatever section holds it; each header and footer is an
    /// entry of its own, named after its section.
    func testSectionsHoldTheirItemsUnderTheirValues() throws {
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(sections: [
            Section(["Apple", "Pear"]) { Text($0) }.id("Fruit").header { Text("Fruit") },
            Section(["Plum"]) { Text($0) }.id("Stone").footer { Text("1 item") },
        ]).node))

        let entries = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertEqual(entries.sections.map(\.identity), ["Fruit", "Stone"], "each section by its id")
        XCTAssertEqual(entries.sections.map(\.header), ["\u{1E}Fruit\u{1E}header", nil])
        XCTAssertEqual(entries.sections.map(\.footer), [nil, "\u{1E}Stone\u{1E}footer"])
        XCTAssertEqual(entries.sections.map(\.items), [["Apple", "Pear"], ["Plum"]])

        let held = try self.list(in: hold(["\u{1E}Fruit\u{1E}header", "Plum"], in: renders, list: list))
        XCTAssertEqual(held.child("\u{1E}Fruit\u{1E}header")?.props[.text], .string("Fruit"))
        XCTAssertEqual(held.child("Plum")?.props[.text], .string("Plum"))
    }

    /// An item moved to another section keeps its identity, so a host moves its cell.
    func testAnItemMovedToAnotherSectionKeepsItsIdentity() throws {
        let shelves = State(wrappedValue: [["Apple", "Pear"], ["Plum"]])
        let renders = Renders()
        let before = try XCTUnwrap(try list(in: renders.render(ShelvesList(shelves: shelves).node))
            .props[.items].flatMap(ItemsEntries.init(propValue:)))

        shelves.wrappedValue = [["Apple"], ["Pear", "Plum"]]
        let after = try XCTUnwrap(try list(in: renders.revisit(changed: Renderer.shared.pendingChanges))
            .props[.items].flatMap(ItemsEntries.init(propValue:)))

        XCTAssertEqual(before.sections.map(\.items), [["Apple", "Pear"], ["Plum"]])
        XCTAssertEqual(after.sections.map(\.items), [["Apple"], ["Pear", "Plum"]])
    }

    /// The same item in two sections is the same item twice, said; one chosen names one row, the first.
    func testTheSameItemInTwoSectionsIsChosenOnce() throws {
        let chosen = State<String?>(wrappedValue: "Quince")
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(sections: [
            Section(["Quince"]) { Text($0) }.id("Fruit"),
            Section(["Quince"]) { Text($0) }.id("Jam"),
        ]).selection(chosen.projectedValue).node))

        let entries = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertEqual(entries.sections.map(\.items), [["Quince"], ["Quince\u{1D}1"]])
        XCTAssertTrue(hasComplained("the same item twice, \"Quince\""))
        XCTAssertEqual(list.props[.selectedItems], .strings(["Quince"]), "one row for one item chosen")
    }

    /// A section is known by its id's value: two ids that describe alike keep their names across a reorder, as two
    /// such items do, and nothing is said of them.
    func testASectionIsKnownByItsIdsValue() throws {
        let order = State(wrappedValue: [Alike(raw: 1), Alike(raw: 2)])
        let renders = Renders()
        let first = try XCTUnwrap(try list(in: renders.render(AlikeSections(order: order).node))
            .props[.items].flatMap(ItemsEntries.init(propValue:))).sections.map(\.identity)

        order.wrappedValue = [Alike(raw: 2), Alike(raw: 1)]
        let second = try XCTUnwrap(try list(in: renders.revisit(changed: Renderer.shared.pendingChanges))
            .props[.items].flatMap(ItemsEntries.init(propValue:))).sections.map(\.identity)

        XCTAssertEqual(Set(first).count, 2, "two ids, two names")
        XCTAssertEqual(second, [first[1], first[0]], "each section kept its name as the order changed")
        XCTAssertFalse(hasComplained("share the id \"item\""), "two values are no repeated id")
    }

    /// A section with no id is named by its place, told apart from a section whose id reads the same - which is no
    /// repeat, and nothing is said of it.
    func testAPlaceReadingAsAnIdIsNoRepeat() throws {
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(sections: [
            Section(["a"]) { Text($0) }, Section(["b"]) { Text($0) }, Section(["c"]) { Text($0) }.id("1"),
        ]).node))

        let entries = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertEqual(entries.sections.map(\.identity), ["0", "1", "1\u{1D}1"])
        XCTAssertFalse(hasComplained("share the id \"1\""))
    }

    /// The same item twice is told apart, as two repeated `.id()`s are, and said.
    func testTheSameItemTwiceIsToldApartAndSaid() throws {
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(["a", "b", "a"], id: \.self) { Text($0) }.node))

        let entries = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertEqual(entries.sections[0].items, ["a", "b", "a\u{1D}1"])
        XCTAssertTrue(hasComplained("the same item twice, \"a\""))
    }

    /// Two items that describe alike but are not equal keep their own identities across a reorder - an item is known
    /// by its value, as ForEach and MotionLayout know theirs - and nothing is said of them.
    func testTwoValuesThatDescribeAlikeKeepTheirIdentitiesAcrossAReorder() throws {
        let order = State(wrappedValue: [Alike(raw: 1), Alike(raw: 2)])
        let renders = Renders()
        let first = try XCTUnwrap(try list(in: renders.render(AlikeList(order: order).node))
            .props[.items].flatMap(ItemsEntries.init(propValue:))).sections[0].items

        order.wrappedValue = [Alike(raw: 2), Alike(raw: 1)]
        let patch = renders.revisit(changed: Renderer.shared.pendingChanges)
        let second = try XCTUnwrap(try list(in: patch).props[.items].flatMap(ItemsEntries.init(propValue:)))
            .sections[0].items

        XCTAssertEqual(Set(first).count, 2, "two values, two identities")
        XCTAssertEqual(second, [first[1], first[0]], "each value kept its identity as the order changed")
        XCTAssertFalse(hasComplained("the same item twice, \"item\""), "two values are no repeated item")
    }

    /// Two sections given one id are told apart, as the same item twice is, and said.
    func testTwoSectionsOfOneIdAreToldApartAndSaid() throws {
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(sections: [
            Section(["a"]) { Text($0) }.id("Shelf"), Section(["b"]) { Text($0) }.id("Shelf"),
        ]).node))

        let entries = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertEqual(entries.sections.map(\.identity), ["Shelf", "Shelf\u{1D}1"])
        XCTAssertTrue(hasComplained("two sections of an ItemsView share the id \"Shelf\""))
    }

    /// GTK and WinUI hand identities to their toolkits as C strings, which end at a NUL: no identity a list makes
    /// holds one - a variant of alike words, of the same item twice, of a section's name, nor an author's own NUL -
    /// so every identity stays its own across that boundary.
    func testNoIdentityHoldsANul() throws {
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(sections: [
            Section([Twin(raw: 1), Twin(raw: 2), Twin(raw: 1)]) { Text("\($0.raw)") }.id("shelf"),
            Section([Twin(raw: 3)]) { Text("\($0.raw)") }.id("shelf").header { Text("Shelf") },
            Section([Twin(raw: 4)]) { Text("\($0.raw)") }.id("a\u{0}b"),
            Section([Twin(raw: 5)]) { Text("\($0.raw)") }.id("a\u{0}c"),
        ]).node))

        let entries = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        for names in [entries.identities, entries.sections.map(\.identity)] {
            let crossed = names.map { $0.prefix { $0 != "\u{0}" } }
            XCTAssertEqual(Set(crossed).count, names.count, "\(names) are not each their own as C strings")
        }
    }

    /// A name the list makes - its header's - is no item's: an item whose words read as one is named apart, so the
    /// header keeps its own state and the item starts with its own.
    func testAnItemWhoseWordsReadAsTheHeadersNameIsNamedApart() throws {
        let renders = Renders()
        func tree(_ items: [String]) -> Node {
            ItemsView(items) { CounterRow(name: "item \($0)") }.header { CounterRow(name: "header") }.node
        }
        let list = try list(in: renders.render(tree(["x"])))
        let before = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        _ = try hold(before.identities, in: renders, list: list)
        renders.fire(try XCTUnwrap(click("header:0", in: renders.renderFromScratch(tree(["x"])))))
        renders.revisit(changed: Renderer.shared.pendingChanges)

        let added = try self.list(in: renders.render(tree(["x", "\u{1E}header"]), changed: Renderer.shared.pendingChanges))
        let after = try XCTUnwrap(added.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertEqual(after.header, before.header, "the header keeps its name")
        _ = try hold(after.identities, in: renders, list: list)
        let captions = captions(in: renders.renderFromScratch(tree(["x", "\u{1E}header"])))
        XCTAssertEqual(captions.sorted(), ["header:1", "item \u{1E}header:0", "item x:0"])
    }

    /// A section whose id's words are empty is no "no section": its header and the list's own are each their own.
    func testASectionOfEmptyWordsKeepsItsHeaderApartFromTheLists() throws {
        let renders = Renders()
        let list = try list(in: renders.render(ItemsView(sections: [
            Section(["a"]) { Text($0) }.id("").header { Text("Section") },
        ]).header { Text("List") }.node))

        let entries = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertEqual(entries.header, "\u{1E}header", "the list's own header is named as with no section")
        XCTAssertNotEqual(entries.sections[0].header, entries.header)
    }

    /// A name an entry stood under in the build before is no new value's: a value coming as one of alike words goes
    /// is named apart, and starts with its own state rather than carrying what the one gone kept.
    func testAValueComingAsOneOfAlikeWordsGoesTakesNoState() throws {
        let order = State(wrappedValue: [Twin(raw: 1)])
        let renders = Renders()
        let list = try list(in: renders.render(CountingTwins(order: order).node))
        let before = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        _ = try hold(before.identities, in: renders, list: list)
        renders.fire(try XCTUnwrap(click("1:0", in: renders.renderFromScratch(CountingTwins(order: order).node))))
        renders.revisit(changed: Renderer.shared.pendingChanges)

        order.wrappedValue = [Twin(raw: 2)]
        renders.revisit(changed: Renderer.shared.pendingChanges)
        let changed = try self.list(in: renders.renderFromScratch(CountingTwins(order: order).node))
        let after = try XCTUnwrap(changed.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertNotEqual(after.identities, before.identities, "another value, another name")
        _ = try hold(after.identities, in: renders, list: list)
        XCTAssertEqual(captions(in: renders.renderFromScratch(CountingTwins(order: order).node)), ["2:0"])
    }

    /// A name a section stood under in the build before is no new section's either: a section coming as one of
    /// alike words goes is named apart, and its header and footer start with their own state.
    func testASectionComingAsOneOfAlikeWordsGoesTakesNoState() throws {
        let which = State(wrappedValue: Twin(raw: 1))
        let renders = Renders()
        let list = try list(in: renders.render(CountingShelf(which: which).node))
        let before = try XCTUnwrap(list.props[.items].flatMap(ItemsEntries.init(propValue:)))
        _ = try hold(before.identities, in: renders, list: list)
        let first = renders.renderFromScratch(CountingShelf(which: which).node)
        renders.fire(try XCTUnwrap(click("header:0", in: first)))
        renders.fire(try XCTUnwrap(click("footer:0", in: first)))
        renders.revisit(changed: Renderer.shared.pendingChanges)

        which.wrappedValue = Twin(raw: 2)
        renders.revisit(changed: Renderer.shared.pendingChanges)
        let changed = try self.list(in: renders.renderFromScratch(CountingShelf(which: which).node))
        let after = try XCTUnwrap(changed.props[.items].flatMap(ItemsEntries.init(propValue:)))
        XCTAssertNotEqual(after.sections[0].identity, before.sections[0].identity, "another section, another name")
        _ = try hold(after.identities, in: renders, list: list)
        XCTAssertEqual(
            captions(in: renders.renderFromScratch(CountingShelf(which: which).node)).sorted(),
            ["footer:0", "header:0", "item:0"])
    }

    /// With no items the list is its empty view; a header alone is no item.
    func testAnEmptyListIsItsEmptyView() throws {
        let renders = Renders()
        let patch = renders.render(ItemsView([Int]()) { Text("\($0)") }
            .header { Text("Numbers") }
            .emptyView { Text("Nothing yet") }.node)

        XCTAssertNil(patch.subtree.first { $0.type == .itemsView })
        XCTAssertEqual(patch.subtree.first { $0.type == .text }?.props[.text], .string("Nothing yet"))
    }

    /// A list kept as a value and given its header in the parent's body shows the header of the parent's last build.
    func testAKeptListShowsTheHeaderItWasLastGiven() throws {
        let title = State(wrappedValue: "First")
        let renders = Renders()
        let list = try list(in: renders.render(TitledList(title: title).node))
        XCTAssertEqual(try texts(in: hold(["\u{1E}header"], in: renders, list: list)), ["First"])

        title.wrappedValue = "Second"
        let patch = renders.revisit(changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(texts(in: patch), ["Second"], "the header says the title the parent gave it last")
    }

    /// Two copies of one list, each given a header of its own, show each its own.
    func testCopiesOfAListShowTheirOwnHeaders() throws {
        let base = ItemsView(["a"]) { Text($0) }
        let renders = Renders()
        let tree = renders.render(VStack {
            base.header { Text("First") }
            base.header { Text("Second") }
        }.node)

        for list in tree.subtree.filter({ $0.type == .itemsView }) {
            renders.fire(try XCTUnwrap(list.events?[.realizedChanged]), with: [.strings(["\u{1E}header"])])
        }
        XCTAssertEqual(texts(in: renders.revisit(changed: Renderer.shared.pendingChanges)), ["First", "Second"])
    }

    /// The words of every text in a patch, in order.
    private func texts(in patch: HostPatch) -> [String] {
        patch.subtree.filter { $0.type == .text }.compactMap { $0.props[.text]?.string }
    }

    /// The words of every button in a patch, in order.
    private func captions(in patch: HostPatch) -> [String] {
        patch.subtree.filter { $0.type == .button }.compactMap { $0.props[.text]?.string }
    }

    /// The click of the button of `caption`, where one stands.
    private func click(_ caption: String, in patch: HostPatch) -> Int? {
        patch.subtree.first { $0.type == .button && $0.props[.text] == .string(caption) }?.events?[.clicked]
    }

    /// The entries round-trip through what crosses.
    func testTheEntriesCrossAndComeBackWhole() {
        let entries = ItemsEntries(header: "h", footer: nil, sections: [
            ItemsEntries.Section("0", header: nil, footer: "f", items: ["1", "2"]),
        ])
        XCTAssertEqual(ItemsEntries(propValue: entries.propValue), entries)
        XCTAssertEqual(entries.identities, ["h", "1", "2", "f"])
        XCTAssertNil(ItemsEntries(propValue: .string("nothing like it")))
    }

    /// A spacing below nought, or not finite, crosses as nought, as a narrowest width does: every host reads it so.
    func testALayoutCrossesItsLengthsAsNoughtAtLeast() {
        let crossed = { (layout: ItemsLayout) in ItemsLayout(propValue: layout.propValue) }
        XCTAssertEqual(crossed(.grid(minimumItemWidth: 100, spacing: -100)), .grid(minimumItemWidth: 100, spacing: 0))
        XCTAssertEqual(crossed(.grid(minimumItemWidth: .nan, spacing: 4)), .grid(minimumItemWidth: 0, spacing: 4))
        XCTAssertEqual(crossed(.list(spacing: .nan)), .list(spacing: 0))
        XCTAssertEqual(crossed(.row(spacing: -.infinity)), .row(spacing: 0))
    }

    /// Each layout crosses as its kind and numbers, and comes back.
    func testALayoutCrossesAndComesBack() {
        for layout: ItemsLayout in [.list(), .list(spacing: 4), .row(spacing: 8), .grid(minimumItemWidth: 120, spacing: 6)] {
            XCTAssertEqual(ItemsLayout(propValue: layout.propValue), layout)
        }
    }
}

/// A value whose words are the same for every value - told apart by itself alone.
private struct Alike: Hashable, CustomStringConvertible {
    let raw: Int
    var description: String { "item" }
}

/// A list kept as a value, given a header from `title` as the parent builds.
private struct TitledList: View {
    let title: State<String>
    let list = ItemsView(["a"]) { Text($0) }

    var body: some View {
        list.header { Text(title.wrappedValue) }
    }
}

/// Sections of the items each shelf holds, each known by its place on the shelves.
private struct ShelvesList: View {
    let shelves: State<[[String]]>

    var body: some View {
        ItemsView(sections: shelves.wrappedValue.enumerated().map { number, items in
            Section(items) { Text($0) }.id(number)
        })
    }
}

/// A section for each of `order`, known by it, built again as the order changes.
private struct AlikeSections: View {
    let order: State<[Alike]>

    var body: some View {
        ItemsView(sections: order.wrappedValue.map { alike in Section(["\(alike.raw)"]) { Text($0) }.id(alike) })
    }
}

/// Another value whose words are the same for every value, so what one test says of it no other test says.
private struct Twin: Hashable, CustomStringConvertible {
    let raw: Int
    var description: String { "twin" }
}

/// A list of `order`, built again as the order changes.
private struct AlikeList: View {
    let order: State<[Alike]>

    var body: some View {
        ItemsView(order.wrappedValue) { Text("\($0.raw)") }
    }
}

/// A row counting its clicks in a state of its own: what a row keeps while it stands.
private struct CounterRow: View {
    let name: String
    @State private var count = 0

    var body: some View {
        Button("\(name):\(count)").onClicked { count += 1 }
    }
}

/// One section of `which`, its header, item and footer each a counting row, built again as the section changes.
private struct CountingShelf: View {
    let which: State<Twin>

    var body: some View {
        ItemsView(sections: [
            Section(["a"]) { _ in CounterRow(name: "item") }
                .id(which.wrappedValue)
                .header { CounterRow(name: "header") }
                .footer { CounterRow(name: "footer") },
        ])
    }
}

/// A list of `order`, each twin a counting row, built again as the order changes.
private struct CountingTwins: View {
    let order: State<[Twin]>

    var body: some View {
        ItemsView(order.wrappedValue) { CounterRow(name: "\($0.raw)") }
    }
}
