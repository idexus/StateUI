// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// An element of the application's own, as it hears the page. Events cross a browser's own page, so the suite runs
/// it in one (`test-web.sh --browser`).
@MainActor
final class WebPageElementTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// AN ELEMENT HEARS ITS OWN EVENTS BY THEIR NAMES: no name is the relay's own - a popover's `closed`, the
    /// keyboard's `focus` coming or going - but the DOM event's.
    func testAnElementHearsItsOwnEventsByTheirNames() throws {
        WebRelay.start()
        let element = WebPageElement(tag: "test-probe")
        let names = ["closed", "focus", "enter", "steps", "itemtap", "dismiss", "key", "shortcut", "activate", "menu"]
        var heard: [String] = []
        for name in names { element.listen(name) { heard.append(name) } }

        for name in names {
            try WebBrowser.run("e.dispatchEvent(new CustomEvent(\(WebBrowser.quoted(name))))", on: element.node)
        }

        XCTAssertEqual(heard, names)
    }
}
