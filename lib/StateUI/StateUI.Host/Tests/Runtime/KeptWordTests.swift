// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A kept value as the words every host's store holds.
@MainActor
final class KeptWordTests: XCTestCase {
    /// A value is kept as the words of its own kind - a whole number whole - and read back as the kind of the key
    /// that reads it; a value no key keeps keeps nothing.
    func testAValueIsKeptAsItsOwnKindAndReadAsItsKeys() {
        XCTAssertEqual(KeptWord.kept([.name("count"), .number(3)])?.word, "3")
        XCTAssertEqual(KeptWord.kept([.name("scale"), .number(1.5)])?.word, "1.5")
        XCTAssertEqual(KeptWord.kept([.name("name"), .string("Ada")])?.word, "Ada")
        XCTAssertEqual(KeptWord.kept([.name("loud"), .bool(true)])?.word, "true")
        XCTAssertNil(KeptWord.kept([.name("points"), .numbers([1, 2])]))

        XCTAssertEqual(KeptWord.restored("3", as: .integer), .number(3))
        XCTAssertEqual(KeptWord.restored("1.5", as: .number), .number(1.5))
        XCTAssertEqual(KeptWord.restored("true", as: .boolean), .bool(true))
        XCTAssertEqual(KeptWord.restored("true", as: .text), .string("true"), "a text that reads as a word")
        XCTAssertNil(KeptWord.restored("three", as: .integer))
    }
}
