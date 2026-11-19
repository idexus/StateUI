// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A write saying what already stands changes nothing in the page, and new words change the one text node in place: a
/// node replaced between a press and its release is a click WebKit never sends. A host runs here, so the suite runs it
/// in a browser (the stateui tool's `WebSuite.inBrowser`).
@MainActor
final class WebRelayWritesTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// What the observer on `element` saw since it was set, each record's kind, a space apart.
    private func seen(on element: Int32) throws -> String {
        WebBrowser.pause()
        return try WebBrowser.evaluate("e.__seen.join(' ')", on: element) ?? ""
    }

    /// Watches `element` and everything under it for every change.
    private func watch(_ element: Int32) throws {
        try WebBrowser.run(
            "e.__seen = []; new MutationObserver((records) => e.__seen.push(...records.map((r) => r.type)))"
                + ".observe(e, { childList: true, characterData: true, attributes: true, subtree: true })",
            on: element)
    }

    /// The same words and the same attributes write nothing; other words change the one text node, not replace it.
    func testAWriteOfWhatStandsChangesNothing() throws {
        let words = WebDOMView(tag: "span")
        defer { words.release() }
        WebRelay.insert(words.node, into: WebRelay.body, at: 0)
        WebRelay.setText(words.node, "Add")
        words.attribute("title", "Add")
        words.attribute("disabled", nil)
        try watch(words.node)

        WebRelay.setText(words.node, "Add")
        words.attribute("title", "Add")
        words.attribute("disabled", nil)
        XCTAssertEqual(try seen(on: words.node), "", "what stood was written again")

        WebRelay.setText(words.node, "Remove")
        XCTAssertEqual(try seen(on: words.node), "characterData", "new words replaced the text node")
        XCTAssertEqual(try WebBrowser.evaluate("e.textContent", on: words.node), "Remove")
    }

    /// A press on a bar's button and its release replace nothing in the bar - its look following the pointer and the
    /// press: the button the pointer stands on keeps every node it had.
    func testAPressOnABarButtonReplacesNothingUnderThePointer() throws {
        WebRenderer.shared?.finish()
        let path = State(wrappedValue: [Int]())
        let host = WebRenderer.running {
            NavigationStack(path.projectedValue) {
                Text("Reasons").toolbar {
                    ToolbarButton("Add").onClicked {}
                        .visualState(.pointerOver) { $0.background(.lightGray) }
                        .visualState(.pressed) { $0.background(.gray) }
                }
            } destination: { _ in
                Text("")
            }
        }
        defer { host.finish() }
        for _ in 0..<5 {
            host.step()
            WebBrowser.pause()
        }
        let bar = "document.querySelector('.stateui-bar')"
        try WebBrowser.run(
            "const b = \(bar); b.__seen = []; new MutationObserver((records) => b.__seen.push(...records.filter("
                + "(r) => r.type !== 'attributes').map((r) => r.type))).observe(b, { childList: true, characterData: true,"
                + " attributes: true, subtree: true })")
        let button = "\(bar).querySelector('button[aria-label=\"Add\"]')"
        for event in ["pointerenter", "pointerdown", "pointerup"] {
            try WebBrowser.run(
                "\(button).dispatchEvent(new PointerEvent('\(event)', { bubbles: true, pointerId: 4, pointerType: 'mouse',"
                    + " isPrimary: true, button: 0, buttons: \(event == "pointerdown" ? 1 : 0) }))")
            for _ in 0..<2 {
                host.step()
                WebBrowser.pause()
            }
        }

        XCTAssertEqual(try WebBrowser.evaluate("\(bar).__seen.join(' ')", on: 0), "", "the press replaced the bar's nodes")
    }
}
