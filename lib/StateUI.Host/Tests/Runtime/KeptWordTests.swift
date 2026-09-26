// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A kept value as the words every host's store holds.
final class KeptWordTests: XCTestCase {
    /// A listed key's value is kept as its key's kind; an unlisted one as its own, read back once its key is listed.
    func testAValueIsKeptAsItsKeysKindElseItsOwn() {
        let keys = [PersistentKey("count", of: Int.self)]
        XCTAssertEqual(KeptWord.kept([.name("count"), .number(3.7)], keys: keys)?.word, "3")
        XCTAssertEqual(KeptWord.kept([.name("name"), .string("Ada")], keys: keys)?.word, "Ada")
        XCTAssertEqual(KeptWord.kept([.name("loud"), .bool(true)], keys: keys)?.word, "true")
        XCTAssertNil(KeptWord.kept([.name("count"), .string("three")], keys: keys), "not of its key's kind")

        let listed = [PersistentKey("name", of: String.self), PersistentKey("loud", of: Bool.self)]
        XCTAssertEqual(
            KeptWord.restored(["name": "Ada", "loud": "true", "stray": "x"], for: listed),
            ["name": .string("Ada"), "loud": .bool(true)])
    }
}
