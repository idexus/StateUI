// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

private struct DescribedItemID: Hashable, CustomStringConvertible {
    let value: Int
    let words: String
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.value == rhs.value }
    func hash(into hasher: inout Hasher) { hasher.combine(value) }
    var description: String { words }
}

@MainActor
final class ItemsIdentityTests: XCTestCase {
    func testEqualLiveSetValuesProduceTheSameItemAndSectionTokens() {
        let values = (0..<64).map { _ in Set(0..<16) }
        XCTAssertEqual(Set(values).count, 1)
        let entries = values.map { value in
            source([Section([value]) { _ in Text("One") }.id(value).header { Text("Header") }]).entries
        }
        XCTAssertTrue(entries.dropFirst().allSatisfy { $0 == entries[0] })
    }

    func testTheDescriptionDoesNotChooseAnItemOrSectionToken() {
        let first = DescribedItemID(value: 1, words: "first")
        let second = DescribedItemID(value: 1, words: "second")
        let one = source([Section([first]) { _ in Text("One") }.id(first).header { Text("Header") }]).entries
        let other = source([Section([second]) { _ in Text("One") }.id(second).header { Text("Header") }]).entries
        XCTAssertEqual(one, other)
    }

    func testItemValuesKeepTheirTokensAndReinsertionsGetNewOnes() {
        let book = ItemsBook<Int>()
        let first = source([Section([1, 2]) { Text("\($0)") }], book: book).entries.sections[0].items
        let reordered = source([Section([2, 1]) { Text("\($0)") }], book: book).entries.sections[0].items
        XCTAssertEqual(reordered, Array(first.reversed()))
        _ = source([Section([2]) { Text("\($0)") }], book: book)
        let returned = source([Section([1, 2]) { Text("\($0)") }], book: book).entries.sections[0].items
        XCTAssertNotEqual(returned[0], first[0])
        XCTAssertEqual(returned[1], first[1])
    }

    func testSectionValuesKeepTheirTokensAndReinsertionsGetNewOnes() {
        let book = ItemsBook<String>()
        func sections(_ values: [Int]) -> [Section<String>] {
            values.map { Section(["\($0)"]) { Text($0) }.id($0) }
        }
        let first = source(sections([1, 2]), book: book).entries.sections.map(\.identity)
        XCTAssertEqual(source(sections([2, 1]), book: book).entries.sections.map(\.identity), Array(first.reversed()))
        _ = source(sections([2]), book: book)
        let returned = source(sections([1, 2]), book: book).entries.sections.map(\.identity)
        XCTAssertNotEqual(returned[0], first[0])
        XCTAssertEqual(returned[1], first[1])
    }

    func testDuplicateItemsKeepTheirOccurrenceTokensWhenACollidingNameLeaves() {
        let book = ItemsBook<String>()
        let one = "x\u{0}", other = "x\u{FFFD}"
        let first = source([Section([one, other, one]) { Text($0) }], book: book).entries.sections[0].items
        let second = source([Section([one, one]) { Text($0) }], book: book).entries.sections[0].items
        let third = source([Section([one, one]) { Text($0) }], book: book).entries.sections[0].items
        XCTAssertEqual(second, [first[0], first[2]])
        XCTAssertEqual(third, second)
    }

    func testDuplicateSectionsKeepTheirOccurrenceTokensWhenACollidingNameLeaves() {
        let book = ItemsBook<Int>()
        let one = "x\u{0}", other = "x\u{FFFD}"
        func sections(_ names: [String]) -> [Section<Int>] {
            names.enumerated().map { index, name in Section([index]) { Text("\($0)") }.id(name) }
        }
        let first = source(sections([one, other, one]), book: book).entries.sections.map(\.identity)
        let second = source(sections([one, one]), book: book).entries.sections.map(\.identity)
        let third = source(sections([one, one]), book: book).entries.sections.map(\.identity)
        XCTAssertEqual(second, [first[0], first[2]])
        XCTAssertEqual(third, second)
    }

    func testItemSectionAndDecorationTokensHaveSeparateDomains() {
        let ids: [AnyHashable] = [Set([1, 2]), "\u{1D}i1", "\u{1D}s1", "\u{1E}header", "", "a\u{0}b"]
        let made = ItemsSource(sections: [
            Section(ids) { _ in Text("One") }.id(Set([1, 2])).header { Text("Section") },
        ])
        made.finish(header: Text("List"), footer: Text("Footer"), book: ItemsBook<AnyHashable>())
        let entries = made.entries
        XCTAssertEqual(Set(entries.identities).count, entries.identities.count)
        XCTAssertFalse(entries.identities.contains { $0.contains("\u{0}") })
        XCTAssertNotEqual(entries.sections[0].identity, entries.sections[0].items[0])
    }

    func testAuthoredStringNamesRemainReadable() {
        let names = ["apple", "plum", "", "a\nb"]
        let entries = source([Section(names) { Text($0) }.id("Fruit")]).entries
        XCTAssertEqual(entries.sections[0].identity, "Fruit")
        XCTAssertEqual(entries.sections[0].items, names)
    }

    private func source<ID: Hashable>(
        _ sections: [Section<ID>], book: ItemsBook<ID> = ItemsBook<ID>()
    ) -> ItemsSource<ID> {
        let result = ItemsSource(sections: sections)
        result.finish(header: nil, footer: nil, book: book)
        return result
    }
}
