// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import StateUITooling
import XCTest

final class OutputLinesTests: XCTestCase {
    /// A line ends at a line feed; a carriage return before it goes with it; an empty line is a line.
    func testALineEndsAtALineFeed() {
        var lines = OutputLines()
        XCTAssertEqual(lines.take(Array("one\ntwo\r\n\nthree".utf8)), ["one", "two", ""])
        XCTAssertEqual(lines.finish(), "three")
        XCTAssertNil(lines.finish())
    }

    /// A line arriving in parts is given once, whole.
    func testALineArrivingInPartsIsGivenWhole() {
        var lines = OutputLines()
        XCTAssertEqual(lines.take(Array("zażó".utf8).dropLast()), [])
        XCTAssertEqual(lines.take(Array("zażó".utf8).suffix(1) + Array("łć\n".utf8)), ["zażółć"])
    }

    /// Bytes that are not UTF-8 read as U+FFFD.
    func testBytesThatAreNotUTF8ReadAsReplacementCharacters() {
        var lines = OutputLines()
        XCTAssertEqual(lines.take([0x61, 0xFF, 0x62, 0x0A]), ["a\u{FFFD}b"])
    }

    /// A line longer than the limit comes in pieces, none cutting a character in two.
    func testALongLineComesInPiecesNoneCuttingACharacter() {
        var lines = OutputLines(limit: 5)
        XCTAssertEqual(lines.take(Array("aaaaéééé\n".utf8)), ["aaaa", "éé", "éé"])
        XCTAssertEqual(lines.take(Array("abcdefghijk".utf8)), ["abcde", "fghij"])
        XCTAssertEqual(lines.finish(), "k")
    }
}
