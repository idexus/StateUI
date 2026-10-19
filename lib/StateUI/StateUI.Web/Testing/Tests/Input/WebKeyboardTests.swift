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
    override func setUp() async throws {
        WebTestLoop.started
    }

    private func press(_ key: String, _ host: WebRenderer) {
        WebBrowser.ask([("key", .words(key))])
        for _ in 0..<3 { host.step() }
    }

    /// An Enter that commits an input method's words submits nothing - Safari tells it as the key of number 229 -
    /// and an Enter after it submits the field.
    func testAnEnterEndingACompositionSubmitsNothing() throws {
        WebRenderer.shared?.leave()
        var submitted = 0
        let words = State(wrappedValue: "")
        let host = WebRenderer.running { TextField(words.projectedValue).onSubmitted { submitted += 1 } }
        host.step()
        let field = try XCTUnwrap(host.views(WebTextInputView.self).first)

        try WebBrowser.run("e.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', isComposing: true }))", on: field.node)
        try WebBrowser.run("e.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 229 }))", on: field.node)
        for _ in 0..<3 { host.step() }
        XCTAssertEqual(submitted, 0, "an input method's Enter submitted the field")

        try WebBrowser.run("e.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }))", on: field.node)
        for _ in 0..<3 { host.step() }
        XCTAssertEqual(submitted, 1)
        host.leave()
    }

    /// A menu that closes gives the keyboard back to what held it as the menu opened, not to the page's body.
    func testAClosedMenuGivesTheKeyboardBack() throws {
        WebRenderer.shared?.leave()
        let host = WebRenderer.running { Button("Share").menu { MenuItem("Mail") } }
        host.step()
        let button = try XCTUnwrap(host.views(WebButtonView.self).first)
        try WebBrowser.run("e.focus(); e.click()", on: button.node)
        for _ in 0..<3 { host.step() }
        XCTAssertTrue(try WebBrowser.truth("!!document.querySelector('.stateui-menu:popover-open')", on: 0), "the menu open")

        try WebBrowser.run("document.querySelector('.stateui-menu:popover-open').hidePopover()")
        for _ in 0..<3 { host.step() }
        XCTAssertTrue(try WebBrowser.truth("document.activeElement === e", on: button.node), "the keyboard back on the button")
        host.leave()
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
                    MenuItem("Ruler").isOn(true)
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
        XCTAssertEqual(try focused(), "Ruler", "a checked one among the others")
        press("ArrowDown", host)
        XCTAssertEqual(try focused(), "Copy", "round to the first")
        press("End", host)
        XCTAssertEqual(try focused(), "Ruler")
    }

    /// An open menu holds the keyboard though the page takes the arrows, Enter and Escape itself: the page's keys are
    /// for the page, not for a menu standing over it.
    func testAMenuKeepsItsKeysFromAPageTakingThem() throws {
        WebRenderer.shared?.leave()
        var taken: [Key] = []
        let host = WebRenderer.running {
            VStack {
                Text("Row").contextMenu {
                    MenuItem("Copy")
                    MenuItem("Paste")
                }
            }
            .onKeyPressed(.downArrow, .upArrow, .return, .escape) { taken.append($0) }
        }
        host.step()
        let row = try XCTUnwrap(host.views(WebTextView.self).first)
        try WebBrowser.run("e.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true }))", on: row.node)
        host.step()

        press("ArrowDown", host)
        XCTAssertEqual(try focused(), "Copy")
        press("ArrowDown", host)
        XCTAssertEqual(try focused(), "Paste")
        XCTAssertEqual(taken, [], "the page took the menu's keys")
        host.leave()
    }
}
