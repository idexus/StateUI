// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIWeb
import XCTest

/// A page keeps no Edit menu of its own: one the page joins holds the field's undoing, clipboard and selection, and
/// they act on the words the user typed into though the bar's More took the focus. The browser holds the clipboard
/// and wants a user's click to cut, so the suite runs it in one (`test-web.sh --browser`), clicking as a mouse does.
@MainActor
final class WebEditMenuTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testTheEditMenuActsOnTheWordsTypedInto() throws {
        WebRenderer.shared?.leave()
        let words = State(wrappedValue: "hello")
        let host = WebRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                VStack { TextField(words.projectedValue) }
                    .menuBar { Menu("Edit") { MenuItem("Find") }.id(StandardMenu.edit) }
                    .title("Notes")
            } destination: { _ in
                Text("Note")
            }
        }
        host.step()
        let field = try XCTUnwrap(host.views(WebTextInputView.self).first)
        try click("e", on: field.node, host)

        try choose("Select All", host)
        try choose("Cut", host)
        settle(host) { words.wrappedValue.isEmpty }
        XCTAssertEqual(words.wrappedValue, "", "the words cut")
        try choose("Paste", host)
        settle(host) { words.wrappedValue == "hello" }
        XCTAssertEqual(words.wrappedValue, "hello", "the clipboard's words pasted back")
        try choose("Undo", host)
        settle(host) { words.wrappedValue.isEmpty }
        XCTAssertEqual(words.wrappedValue, "", "the paste undone")
        host.leave()
    }

    /// The bar's More opened, its Edit menu, and the entry captioned `caption` clicked.
    private func choose(_ caption: String, _ host: WebRenderer) throws {
        try click("document.querySelector('button[aria-label=\"More\"]')", host)
        try click(
            "[...document.querySelectorAll('.stateui-menu:popover-open [aria-haspopup=menu]')]"
                + ".find((b) => b.textContent === 'Edit')", host)
        try click(
            "[...document.querySelectorAll('.stateui-menu:popover-open [role=menuitem]')]"
                + ".find((b) => b.textContent.startsWith('\(caption)'))", host)
    }

    /// The mouse clicks the middle of what `found` finds - `e` the element `element` - as a user's does.
    private func click(_ found: String, on element: Int32 = 0, _ host: WebRenderer) throws {
        let middle = try WebBrowser.evaluate(
            "((t) => { if (!t) return ''; const r = t.getBoundingClientRect(); "
                + "return [r.x + r.width / 2, r.y + r.height / 2].join(','); })(\(found))", on: element) ?? ""
        let point = middle.split(separator: ",").compactMap { Double($0) }
        guard point.count == 2 else { return XCTFail("nothing to click: \(found)") }
        for type in ["mousePressed", "mouseReleased"] {
            WebBrowser.ask([
                ("mouse", .words(type)), ("x", .number(point[0])), ("y", .number(point[1])), ("count", .number(1)),
                ("held", .truth(false)), ("deltaY", .number(0)), ("modifiers", .number(0)), ("button", .words("left")),
            ])
        }
        for _ in 0..<3 { host.step() }
    }

    /// Steps the page until `done`, a few seconds at most.
    private func settle(_ host: WebRenderer, until done: () -> Bool) {
        for _ in 0..<100 where !done() {
            host.step()
            WebBrowser.pause()
        }
    }
}
