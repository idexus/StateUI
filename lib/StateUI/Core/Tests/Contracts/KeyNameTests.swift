// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

final class KeyNameTests: XCTestCase {
    /// A key's number is its name's 64-bit FNV-1a hash, so one name has one number in every process on every platform.
    func testAKeysNumberIsItsNamesFNV1aHash() {
        XCTAssertEqual(KeyNumbers.number(of: ""), 0xcbf2_9ce4_8422_2325)
        XCTAssertEqual(KeyNumbers.number(of: "a"), 0xaf63_dc4c_8601_ec8c)
        XCTAssertEqual(KeyNumbers.number(of: "foobar"), 0x8594_4171_f739_67e8)
        XCTAssertEqual(KeyName("text").number, 0xfa04_f4ef_1995_407e)
    }

    /// Keys of one name are one key, hashed alike; keys of two names are two.
    func testKeysOfOneNameAreOneKey() {
        XCTAssertEqual(KeyName("opacity"), KeyName("opacity"))
        XCTAssertEqual(KeyName("opacity").hashValue, KeyName("opacity").hashValue)
        XCTAssertNotEqual(KeyName("opacity"), KeyName("margin"))
        XCTAssertNotEqual(KeyName("text"), KeyName("Text"))
        XCTAssertEqual(Set([KeyName("a"), KeyName("b"), KeyName("a")]).count, 2)
    }

    /// Keys order by name, whatever their numbers: a sorted list reads alike in every process.
    func testKeysOrderByName() {
        let names = ["b", "a", "foobar", "Text", "text", ""]

        XCTAssertEqual(names.map(KeyName.init).sorted().map(\.name), names.sorted())
    }

    /// Two names that are the same text to `String` but other bytes - "é" composed and decomposed - are two keys,
    /// and one of them comes first: the order is the bytes', as the equality is.
    func testKeysOfTwoSpellingsOfOneTextAreOrdered() {
        let composed = KeyName("caf\u{E9}")
        let decomposed = KeyName("cafe\u{301}")

        XCTAssertNotEqual(composed, decomposed)
        XCTAssertTrue(composed < decomposed || decomposed < composed, "one of them comes first")
    }

    /// A number one name holds is refused to another name; the name itself takes it again.
    func testANumberHeldIsRefusedToAnotherName() {
        var numbers = KeyNumbers()

        XCTAssertNil(numbers.take(7, for: "one"))
        XCTAssertNil(numbers.take(7, for: "one"))
        XCTAssertEqual(numbers.take(7, for: "two"), "one")
        XCTAssertNil(numbers.take(8, for: "two"))
    }

    /// Every name the library makes a key of - its node types, its contracts, their members, the visual states -
    /// has a number of its own.
    func testEveryNameTheLibraryKeysHasANumberOfItsOwn() {
        let contracts = LibraryContracts.tiers + LibraryContracts.elements.map { $0 as any Contract.Type }
        var names = Set(contracts.map { $0.name })
        for contract in contracts { names.formUnion(contract.members.map { $0.name }) }
        names.formUnion(LibraryContracts.elements.map { $0.nodeType.name })
        names.formUnion(VisualStateRules.precedence.map(\.name))

        var holders: [UInt64: String] = [:]
        var clashes: [String] = []
        for name in names.sorted() {
            if let holder = holders.updateValue(name, forKey: KeyNumbers.number(of: name)) {
                clashes.append("\(holder) and \(name)")
            }
        }

        XCTAssertGreaterThan(names.count, 300, "the library's names were read")
        XCTAssertEqual(clashes, [])
    }
}
