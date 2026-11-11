// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIConformance
import XCTest

/// A host runs here, so the suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebVocabularyTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// Every case of every closed vocabulary, written to each element wearing it, is taken: the page stands and the
    /// log says nothing.
    func testEveryCaseOfEveryClosedVocabularyIsTaken() throws {
        XCTAssertEqual(try ClosedVocabularies.untaken(on: WebDriver()), [])
    }
}
