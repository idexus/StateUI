// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

final class KeptValuesTextTests: XCTestCase {
    private let keys = [
        PersistentKey("kept.count", of: Int.self), PersistentKey("kept.name", of: String.self),
        PersistentKey("kept.loud", of: Bool.self), PersistentKey("kept.scale", of: Double.self),
    ]

    /// Every kind is kept as words and restored as its kind; the same values write the same text, keys in order.
    func testEveryKindComesBackAsItself() {
        var kept = KeptValuesText("")
        XCTAssertTrue(kept.keep([.name("kept.name"), .string("Ann")], keys: keys))
        XCTAssertTrue(kept.keep([.name("kept.count"), .number(3)], keys: keys))
        XCTAssertTrue(kept.keep([.name("kept.loud"), .bool(true)], keys: keys))
        XCTAssertTrue(kept.keep([.name("kept.scale"), .number(1.5)], keys: keys))

        XCTAssertEqual(kept.text, "kept.count\t3\nkept.loud\ttrue\nkept.name\tAnn\nkept.scale\t1.5\n")
        XCTAssertEqual(KeptValuesText(kept.text).restored(for: keys), [
            "kept.count": .number(3), "kept.name": .string("Ann"), "kept.loud": .bool(true), "kept.scale": .number(1.5),
        ])
    }

    /// Words holding a tab, a line's end or a backslash come back whole.
    func testEscapedWordsComeBackWhole() {
        var kept = KeptValuesText("")
        kept.keep([.name("kept.name"), .string("a\tb\nc\\d\re")], keys: keys)

        XCTAssertEqual(kept.text.split(separator: "\n").count, 1, "one line a key")
        XCTAssertEqual(KeptValuesText(kept.text).restored(for: keys)["kept.name"], .string("a\tb\nc\\d\re"))
    }

    /// A key the application does not list still saves, as its value's own kind, and reads back as the kind its key
    /// says once it is listed: its value comes one launch late.
    func testAKeyLeftOffTheListStillSaves() {
        var kept = KeptValuesText("")
        XCTAssertTrue(kept.keep([.name("late.count"), .number(2)], keys: keys))
        XCTAssertTrue(kept.keep([.name("late.name"), .string("Ann")], keys: keys))
        XCTAssertTrue(kept.keep([.name("late.loud"), .bool(false)], keys: keys))

        let listed = [
            PersistentKey("late.count", of: Int.self), PersistentKey("late.name", of: String.self),
            PersistentKey("late.loud", of: Bool.self),
        ]
        XCTAssertEqual(KeptValuesText(kept.text).restored(for: listed), [
            "late.count": .number(2), "late.name": .string("Ann"), "late.loud": .bool(false),
        ])
    }

    /// A value of another kind than its key's, or of a kind no key keeps, is not kept; a line that is no key and
    /// words is passed over.
    func testWhatIsNoKeptValueIsLeftOut() {
        var kept = KeptValuesText("stray line\nkept.count\t4\n")
        XCTAssertFalse(kept.keep([.name("kept.count"), .string("four")], keys: keys))
        XCTAssertFalse(kept.keep([.name("other.key"), .numbers([1, 2])], keys: keys))

        XCTAssertEqual(kept.words, ["kept.count": "4"])
    }
}
