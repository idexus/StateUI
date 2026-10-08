// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIWeb
import XCTest

/// The keyboard in a strip of tabs and in a menu: the arrows go from one to the next, Home and End to the ends, a tab
/// chosen as the keyboard reaches it. The browser takes the keys, so the suite runs it in a browser
/// (`test-web.sh --browser`).
@MainActor
final class WebKeyboardTests: XCTestCase {
    override func setUp() {
        WebTestLoop.started
    }

    private func press(_ key: String, _ host: WebRenderer) {
        WebBrowser.ask([("key", .words(key))])
        for _ in 0..<3 { host.step() }
    }

    private func focused() throws -> String {
        try WebBrowser.evaluate("document.activeElement?.textContent ?? ''", on: 0) ?? ""
    }

    func testTheArrowsChooseTheNextTab() throws {
        let host = WebRenderer.running { TabView([0, 1, 2]) { tab in Text("Page \(tab)").title("Tab \(tab)") } }
        host.step()
        let tabs = try XCTUnwrap(host.views(WebTabView.self).first)
        let strip = ":scope > .stateui-tab-strip > [role=tab]"
        try WebBrowser.run("e.querySelector('\(strip)').focus()", on: tabs.node)

        press("ArrowRight", host)
        XCTAssertEqual(try focused(), "Tab 1")
        XCTAssertEqual(try WebBrowser.evaluate("e.querySelectorAll('\(strip)')[1].ariaSelected", on: tabs.node), "true")
        press("End", host)
        XCTAssertEqual(try focused(), "Tab 2")
        press("Home", host)
        XCTAssertEqual(try focused(), "Tab 0")
        XCTAssertEqual(
            try WebBrowser.evaluate("[...e.querySelectorAll('\(strip)')].map((t) => t.tabIndex).join(' ')", on: tabs.node),
            "0 -1 -1", "the keyboard comes to the chosen tab alone")
    }

    func testTheArrowsGoThroughAMenu() throws {
        let host = WebRenderer.running {
            VStack {
                Text("Row").contextMenu {
                    MenuItem("Copy")
                    MenuItem("Cut").isEnabled(false)
                    MenuItem("Paste")
                }
            }
        }
        host.step()
        let row = try XCTUnwrap(host.views(WebTextView.self).first)
        try WebBrowser.run("e.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true }))", on: row.node)
        host.step()

        press("ArrowDown", host)
        XCTAssertEqual(try focused(), "Copy")
        press("ArrowDown", host)
        XCTAssertEqual(try focused(), "Paste", "past the one that cannot be chosen")
        press("ArrowDown", host)
        XCTAssertEqual(try focused(), "Copy", "round to the first")
        press("End", host)
        XCTAssertEqual(try focused(), "Paste")
    }
}
