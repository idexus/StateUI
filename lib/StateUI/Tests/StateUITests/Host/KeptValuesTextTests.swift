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

    /// A key the application does not list, or a value of another kind than its key's, is not kept; a line
    /// that is no key and words is passed over.
    func testWhatIsNoKeptValueIsLeftOut() {
        var kept = KeptValuesText("stray line\nkept.count\t4\n")
        XCTAssertFalse(kept.keep([.name("other.key"), .number(1)], keys: keys))
        XCTAssertFalse(kept.keep([.name("kept.count"), .string("four")], keys: keys))

        XCTAssertEqual(kept.words, ["kept.count": "4"])
    }
}
