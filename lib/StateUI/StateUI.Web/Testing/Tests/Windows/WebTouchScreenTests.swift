// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// The page on a touch screen: its pointer a finger, which hovers nowhere. The browser draws, so the suite runs it in a
/// browser (the stateui tool's `WebSuite.inBrowser`), on a tab of its own - a touch screen stands for the rest of its
/// run.
@MainActor
final class WebTouchScreenTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// On a touch screen a button the user tapped is not left lit: what lights a button under the pointer waits for a
    /// pointer that hovers, which a finger is not - the browser holds the tapped one hovered till the next tap.
    func testATappedButtonIsNotLeftLitOnATouchScreen() throws {
        WebBrowser.ask([("touchScreen", .truth(true))])
        XCTAssertFalse(try WebBrowser.truth("matchMedia('(any-hover: hover)').matches", on: 0), "a finger hovers nowhere")
        let host = WebRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root").pageTitle("Notes").toolbar { ToolbarButton("Save") }
            } destination: { _ in Text("Pushed") }
        }
        let save = "[...document.querySelectorAll('.stateui-window > .stateui-bar button')]"
            + ".find((b) => b.innerText.trim() === 'Save')"
        host.settle { (try? WebBrowser.truth("!!\(save)", on: 0)) == true }
        // The button's fade is taken out, so its color reads at once.
        try WebBrowser.run("\(save).style.transition = 'none'")
        let ground = try XCTUnwrap(WebBrowser.evaluate("getComputedStyle(\(save)).backgroundColor", on: 0))
        let middle = try XCTUnwrap(WebBrowser.evaluate(
            "(() => { const r = \(save).getBoundingClientRect(); return (r.left + r.width / 2) + ',' + (r.top + r.height / 2); })()",
            on: 0)).split(separator: ",").compactMap { Double($0) }

        WebBrowser.ask([("touch", .words("touchStart")), ("points", .points([Point(x: middle[0], y: middle[1])]))])
        WebBrowser.ask([("touch", .words("touchEnd")), ("points", .points([]))])
        let lit = { try WebBrowser.evaluate("getComputedStyle(\(save)).backgroundColor", on: 0) }
        // The press's own light goes as the finger lifts; what stays is the browser's hover.
        host.settle { (try? WebBrowser.truth("\(save).matches(':active')", on: 0)) == false }

        XCTAssertTrue(try WebBrowser.truth("\(save).matches(':hover')", on: 0), "the browser holds the tapped button hovered")
        XCTAssertEqual(try lit(), ground, "and leaves it unlit")
    }
}
