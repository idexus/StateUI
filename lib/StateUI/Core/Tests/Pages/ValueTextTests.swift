// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import StateUI
import XCTest

/// A window's value written down as text and read back: what a restored window is opened for. A value that does not
/// read back loses its window on restoration.
final class ValueTextTests: XCTestCase {
    /// Every shape a `Codable` value takes comes back as it went: nested values, lists, maps, an absent and a present
    /// optional, whole numbers of every width, fractions, a raw-valued choice, and a subclass with its superclass's
    /// members.
    func testEveryCodableShapeComesBackAsItWent() throws {
        let value = Shapes(
            name: "Ada", count: -3, big: Int64.max, small: 200, ratio: 0.1, rough: 2.5, on: true, missing: nil,
            present: 7, list: [1, 2, 3], nested: [[], [Inner(tag: "a")]], map: ["one": 1, "two": 2],
            choice: .second, inner: Inner(tag: "deep"))

        XCTAssertEqual(ValueText.read(Shapes.self, from: try ValueText.write(value)), value)
        XCTAssertEqual(ValueText.read([Int].self, from: try ValueText.write([Int]())), [], "an empty list")
        XCTAssertEqual(ValueText.read(Double.self, from: try ValueText.write(-1.5e-7)), -1.5e-7)

        let subclass = Derived(base: 4, extra: "more")
        let back = try XCTUnwrap(ValueText.read(Derived.self, from: try ValueText.write(subclass)))
        XCTAssertEqual(back.base, 4, "the superclass's member, under its own key")
        XCTAssertEqual(back.extra, "more")
    }

    /// Words come back whole: a quote, a backslash, a line's end, a tab, a control with no letter, a letter past the
    /// first plane; and a pair of halves written by another hand reads as the one letter it stands for.
    func testEscapedWordsComeBackWhole() throws {
        for words in ["say \"hi\"", "a\\b", "one\ntwo\r", "a\tb", "bell \u{07}", "zażółć 😀", "", "/"] {
            XCTAssertEqual(ValueText.read(String.self, from: try ValueText.write(words)), words, words)
        }
        XCTAssertEqual(ValueText.read(String.self, from: "\"\\ud83d\\ude00 \\u0041\\/\""), "😀 A/")
    }

    /// Text that is no JSON, or no value of the type asked, reads as nothing - never as a value half read; and a
    /// number JSON cannot say is refused as it is written.
    func testTextThatIsNoJSONReadsAsNothing() {
        for text in ["", "{", "[1,", "\"open", "\"\\x\"", "\"\\ud83d\"", "\"\\u12\"", "1 2", "1-2", "tru", "{\"a\" 1}"] {
            XCTAssertNil(ValueText.read(Int.self, from: text) as Int?, text)
            XCTAssertNil(ValueText.read(String.self, from: text) as String?, text)
        }
        XCTAssertNil(ValueText.read(Int.self, from: "\"7\""), "words are no number")
        XCTAssertNil(ValueText.read(Inner.self, from: "{}"), "a member missing")
        XCTAssertThrowsError(try ValueText.write(Double.infinity))
        XCTAssertThrowsError(try ValueText.write([Double.nan]))
    }
}

private struct Inner: Codable, Equatable {
    let tag: String
}

private enum Choice: String, Codable {
    case first, second
}

private struct Shapes: Codable, Equatable {
    let name: String
    let count: Int
    let big: Int64
    let small: UInt8
    let ratio: Double
    let rough: Float
    let on: Bool
    let missing: Int?
    let present: Int?
    let list: [Int]
    let nested: [[Inner]]
    let map: [String: Int]
    let choice: Choice
    let inner: Inner
}

private class Base: Codable {
    let base: Int

    init(base: Int) {
        self.base = base
    }
}

private final class Derived: Base {
    let extra: String

    private enum Keys: String, CodingKey {
        case extra
    }

    init(base: Int, extra: String) {
        self.extra = extra
        super.init(base: base)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        extra = try container.decode(String.self, forKey: .extra)
        try super.init(from: container.superDecoder())
    }

    override func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(extra, forKey: .extra)
        try super.encode(to: container.superEncoder())
    }
}
