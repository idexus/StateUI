// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIConformance
import XCTest

@MainActor
final class UIKitVocabularyTests: XCTestCase {
    /// Every case of every closed vocabulary, written to each element wearing it, is taken: the page stands and the
    /// log says nothing.
    func testEveryCaseOfEveryClosedVocabularyIsTaken() throws {
        let driver = UIKitDriver()
        defer { driver.close() }
        XCTAssertEqual(try ClosedVocabularies.untaken(on: driver), [])
    }
}
