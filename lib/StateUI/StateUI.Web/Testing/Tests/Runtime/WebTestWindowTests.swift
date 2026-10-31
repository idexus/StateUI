// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUITesting
import XCTest

/// An application's test window walked through the browser's own elements: the same test reads alike here and with
/// no toolkit. A host runs here, so the suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebTestWindowTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testATestWindowWalksOnTheWeb() {
        XCTAssertEqual(TestWindowWalk.failures(on: WebDriver()), [])
    }
}
