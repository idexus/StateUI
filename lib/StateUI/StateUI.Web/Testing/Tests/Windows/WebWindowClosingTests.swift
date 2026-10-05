// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A window closing takes the sheets over it away: each is a modal dialog of the page's, which would hold every page
/// after it still. A host runs here, so the suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebWindowClosingTests: XCTestCase {
    override func setUp() {
        WebTestLoop.started
    }

    func testAWindowClosingTakesItsSheetsAway() throws {
        let host = WebRenderer.running {
            ModalStack(State(wrappedValue: [1, 2]).projectedValue) {
                Text("Beneath")
            } destination: { number in
                Text("On sheet \(number)")
            }
        }
        host.settle { (try? WebBrowser.number("document.querySelectorAll('dialog[open]').length", on: 0)) == 2 }
        XCTAssertEqual(try WebBrowser.number("document.querySelectorAll('dialog[open]').length", on: 0), 2, "two sheets shown")

        host.leave()

        XCTAssertEqual(try WebBrowser.number("document.querySelectorAll('dialog[open]').length", on: 0), 0,
                       "no sheet of the closed window holds the page")
    }
}
