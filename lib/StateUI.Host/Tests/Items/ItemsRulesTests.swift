// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUIHost
import XCTest

/// The rules every host's collection keeps alike: the changes told one by one, the end reached, a grid's columns.
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

    /// The end is told once as the last item in view comes within reach of the last of all; again only after the
    /// user scrolled away, or once the list gained items.
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
