// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import StateUIWeb
import XCTest

/// The page goes back over its own entry of the browser's history alone: from one it did not put there, going back
/// would take the user off the site. The browser's history is the page's, so the suite runs it in a browser
/// (`test-web.sh --browser`).
@MainActor
final class WebHistoryTests: XCTestCase {
    override func setUp() {
        WebTestLoop.started
    }

    func testThePageGoesBackOnlyOverItsOwnEntry() throws {
        try WebBrowser.run("history.replaceState(null, '')")
        XCTAssertFalse(WebRelay.backHistory(), "no entry of the page's own to go back over")

        WebRelay.pushHistory()
        XCTAssertTrue(WebRelay.backHistory(), "over its own entry")
        for _ in 0..<3 { WebBrowser.pause() }
        XCTAssertEqual(try WebBrowser.evaluate("location.protocol", on: 0), "http:", "still on the site")
    }
}
