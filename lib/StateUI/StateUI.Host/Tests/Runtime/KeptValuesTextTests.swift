// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

@MainActor
final class KeptValuesTextTests: XCTestCase {
    /// Every kind is kept as words and read back as the kind its key asks for; the same values write the same text,
    /// keys in order.
    func testEveryKindComesBackAsItself() {
        var kept = KeptValuesText("")
        XCTAssertTrue(kept.keep([.name("kept.name"), .string("Ann")]))
        XCTAssertTrue(kept.keep([.name("kept.count"), .number(3)]))
        XCTAssertTrue(kept.keep([.name("kept.loud"), .bool(true)]))
        XCTAssertTrue(kept.keep([.name("kept.scale"), .number(1.5)]))

        XCTAssertEqual(kept.text, "kept.count\t3\nkept.loud\ttrue\nkept.name\tAnn\nkept.scale\t1.5\n")
        let read = KeptValuesText(kept.text)
        XCTAssertEqual(read.value(named: "kept.count", as: .integer), .number(3))
        XCTAssertEqual(read.value(named: "kept.name", as: .text), .string("Ann"))
        XCTAssertEqual(read.value(named: "kept.loud", as: .boolean), .bool(true))
        XCTAssertEqual(read.value(named: "kept.scale", as: .number), .number(1.5))
        XCTAssertNil(read.value(named: "kept.other", as: .text), "a name the store never kept")
    }

    /// Words holding a tab, a line's end or a backslash come back whole.
    func testEscapedWordsComeBackWhole() {
        var kept = KeptValuesText("")
        kept.keep([.name("kept.name"), .string("a\tb\nc\\d\re")])

        XCTAssertEqual(kept.text.split(separator: "\n").count, 1, "one line a key")
        XCTAssertEqual(KeptValuesText(kept.text).value(named: "kept.name", as: .text), .string("a\tb\nc\\d\re"))
    }

    /// A value of a kind no key keeps is not kept; a line that is no key and words is passed over.
    func testWhatIsNoKeptValueIsLeftOut() {
        var kept = KeptValuesText("stray line\nkept.count\t4\n")
        XCTAssertFalse(kept.keep([.name("other.key"), .numbers([1, 2])]))

        XCTAssertEqual(kept.words, ["kept.count": "4"])
    }
}
