// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The rules every host's collection keeps alike: the changes told one by one, the end reached, a grid's columns.
@MainActor
final class ItemsRulesTests: XCTestCase {
    /// Removals come last first from the old list, insertions first first into the new one, and a list applied
    /// that way comes out as the new list.
    func testChangesTurnTheOldListIntoTheNew() {
        let cases: [([String], [String])] = [
            ([], ["a", "b"]), (["a", "b"], []), (["a", "b", "c"], ["a", "c"]), (["a", "c"], ["a", "b", "c"]),
            (["a", "b", "c", "d"], ["d", "a", "b", "c"]), (["a", "b", "c"], ["c", "b", "a"]),
            (["a", "b", "c"], ["a", "b", "c"]), (["x", "a", "y", "b"], ["b", "a", "z"]),
        ]
        for (old, new) in cases {
            let changes = ItemsChanges(from: old, to: new)
            var list = old
            for position in changes.removed { list.remove(at: position) }
            for position in changes.inserted { list.insert(new[position], at: position) }
            XCTAssertEqual(list, new, "\(old) to \(new)")
            XCTAssertEqual(changes.removed, changes.removed.sorted(by: >), "removals last first")
            XCTAssertEqual(changes.inserted, changes.inserted.sorted(), "insertions first first")
        }
    }

    /// An entry that keeps its place against the others is neither removed nor inserted; one moved is both.
    func testOnlyWhatMovedIsRemovedAndInserted() {
        XCTAssertTrue(ItemsChanges(from: ["a", "b", "c"], to: ["a", "b", "c"]).isEmpty)
        let added = ItemsChanges(from: ["a", "b", "c"], to: ["a", "x", "b", "c"])
        XCTAssertEqual(added.removed, [])
        XCTAssertEqual(added.inserted, [1])
        let moved = ItemsChanges(from: ["a", "b", "c", "d"], to: ["d", "a", "b", "c"])
        XCTAssertEqual(moved.removed, [3])
        XCTAssertEqual(moved.inserted, [0])
    }

    /// Removals and insertions come as runs of neighbours, in the order they are told.
    func testChangesComeInRunsOfNeighbours() {
        let changes = ItemsChanges(from: ["a", "b", "c", "d", "e", "f"], to: ["a", "x", "y", "d", "z"])
        XCTAssertEqual(changes.removed, [5, 4, 2, 1])
        XCTAssertEqual(changes.removedRuns, [4..<6, 1..<3], "last first")
        XCTAssertEqual(changes.inserted, [1, 2, 4])
        XCTAssertEqual(changes.insertedRuns, [1..<3, 4..<5], "first first")
    }

    /// A tap chooses the item as the list's mode says, and opens it unless it changes a choice of many.
    func testATapChoosesAndOpensAsTheModeSays() {
        let taps = [
            ItemsTap(on: "b", mode: .none, chosen: []), ItemsTap(on: "b", mode: .single, chosen: ["a"]),
            ItemsTap(on: "b", mode: .multiple, chosen: ["a"]), ItemsTap(on: "a", mode: .multiple, chosen: ["a", "b"]),
        ]
        XCTAssertEqual(taps.map(\.chosen), [nil, ["b"], ["a", "b"], ["b"]])
        XCTAssertEqual(taps.map(\.opens), [true, true, false, false])
    }

    /// An item stands at the start, the centre or the end of the room; nearest moves it only where it is not wholly
    /// in view, the shorter way.
    func testAnAnchorPlacesTheItem() {
        XCTAssertEqual(ScrollAnchor.start.place(of: 500, length: 40, in: 300, at: 0), 500)
        XCTAssertEqual(ScrollAnchor.center.place(of: 500, length: 40, in: 300, at: 0), 370)
        XCTAssertEqual(ScrollAnchor.end.place(of: 500, length: 40, in: 300, at: 0), 240)
        XCTAssertNil(ScrollAnchor.nearest.place(of: 100, length: 40, in: 300, at: 0), "wholly in view")
        XCTAssertEqual(ScrollAnchor.nearest.place(of: 500, length: 40, in: 300, at: 0), 240, "below: to the end")
        XCTAssertEqual(ScrollAnchor.nearest.place(of: 100, length: 40, in: 300, at: 400), 100, "above: to the start")
    }

    /// In a list the items of a group stand `spacing` apart, a header or a footer keeps no room, and a row spaces
    /// its items across.
    func testAListSpacesTheItemsOfAGroup() {
        let entries = ItemsEntries(sections: [
            .init(header: "h", items: ["a", "b"]), .init(items: ["c", "d"]),
        ])
        let list = ItemsPlacement(entries, layout: .list(spacing: 6), width: 300, spanning: true)
        XCTAssertEqual(list.edges, [true, false, false, false, false])
        XCTAssertEqual(list.rooms.map(\.top), [0, 0, 6, 0, 6])
        XCTAssertEqual(list.spans, [1, 1, 1, 1, 1])
        let row = ItemsPlacement(entries, layout: .row(spacing: 8), width: 300, spanning: true)
        XCTAssertEqual(row.rooms.map(\.leading), [0, 0, 8, 0, 8])
    }

    /// Spanning, a grid's header spans every column and a group's last item what its row has left; each item is a
    /// column's width, `spacing` from the next.
    func testAGridGroupStartsARowWhereEntriesSpan() {
        let entries = ItemsEntries(sections: [.init(items: ["a", "b", "c", "d"]), .init(header: "h", items: ["e"])])
        let grid = ItemsPlacement(entries, layout: .grid(minimumItemWidth: 90, spacing: 10), width: 300, spanning: true)
        XCTAssertEqual(grid.columns, 3)
        XCTAssertEqual(grid.spans, [1, 1, 1, 3, 3, 3], "the fourth fills its row; the header all; the last its row")
        let itemWidth = (300.0 - 20) / 3
        for (place, room) in grid.rooms.enumerated() where !grid.edges[place] {
            let width = Double(grid.spans[place]) * 100 - room.leading - room.trailing
            XCTAssertEqual(width, itemWidth, accuracy: 0.001, "entry \(place) a column's width")
        }
        XCTAssertEqual(grid.rooms[1].leading, 10.0 / 3, accuracy: 0.001, "ten from the first")
        XCTAssertEqual(grid.rooms.map(\.top), [0, 0, 0, 10, 0, 0])
    }

    /// Without spanning, every entry takes the next cell, a header too.
    func testAGridWithoutSpanningTakesTheNextCell() {
        let entries = ItemsEntries(sections: [.init(header: "h", items: ["a", "b", "c"])])
        let grid = ItemsPlacement(entries, layout: .grid(minimumItemWidth: 90, spacing: 10), width: 300, spanning: false)
        XCTAssertEqual(grid.spans, [1, 1, 1, 1])
        XCTAssertEqual(grid.rooms.map(\.top), [0, 0, 0, 10])
        XCTAssertEqual(grid.rooms[3].leading, 0, "the fourth cell starts the second row")
    }

    /// The end is told once as the last item in view comes within reach of the last of all; again only after the
    /// user scrolled away, or once the list gained or lost items.
    func testTheEndIsToldOnceUntilTheUserLeavesItOrMoreArrive() {
        var watch = EndReachedWatch()
        XCTAssertFalse(watch.reached(count: 30, last: 20, within: 5))
        XCTAssertTrue(watch.reached(count: 30, last: 24, within: 5), "within five of the last")
        XCTAssertFalse(watch.reached(count: 30, last: 29, within: 5), "told once")
        XCTAssertFalse(watch.reached(count: 30, last: 10, within: 5))
        XCTAssertTrue(watch.reached(count: 30, last: 26, within: 5), "again, after leaving it")
        XCTAssertTrue(watch.reached(count: 60, last: 29, within: 30), "again, once more arrived")
        XCTAssertFalse(watch.reached(count: 0, last: -1, within: 5), "an empty list has no end")
    }

    /// A grid holds as many columns as fit its narrowest item, one at least, the columns sharing the rest.
    func testAGridHoldsTheColumnsItsWidthFits() {
        XCTAssertEqual(ItemsGrid.columns(width: 400, minimumItemWidth: 120, spacing: 8), 3)
        XCTAssertEqual(ItemsGrid.columns(width: 376, minimumItemWidth: 120, spacing: 8), 3, "exactly three")
        XCTAssertEqual(ItemsGrid.columns(width: 375, minimumItemWidth: 120, spacing: 8), 2)
        XCTAssertEqual(ItemsGrid.columns(width: 80, minimumItemWidth: 120, spacing: 8), 1, "one at least")
        XCTAssertEqual(ItemsGrid.columnWidth(width: 400, columns: 3, spacing: 8), 128)
    }
}
