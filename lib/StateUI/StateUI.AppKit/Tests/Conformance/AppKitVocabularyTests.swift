// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) import StateUIConformance
import XCTest

final class AppKitVocabularyTests: XCTestCase {
    /// Every case of every closed vocabulary, written to each element wearing it, is taken: the page stands and the
    /// log says nothing.
    @MainActor
    func testEveryCaseOfEveryClosedVocabularyIsTaken() throws {
        let driver = AppKitDriver()
        defer { driver.renderer?.finish() }
        XCTAssertEqual(try ClosedVocabularies.untaken(on: driver), [])
    }
}

#endif
