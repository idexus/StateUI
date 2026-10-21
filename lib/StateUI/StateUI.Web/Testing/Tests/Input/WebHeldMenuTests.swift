// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIWeb
import XCTest

/// A view's menu a held finger opens, as a phone's browser holds one: the hold is the menu's - none of the view's
/// words chosen by it - and the finger lifting is no touch beside the menu, which stays until one comes.
@MainActor
final class WebHeldMenuTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testAMenuAHeldFingerOpensStaysAsTheFingerLifts() throws {
        WebRenderer.shared?.leave()
        let host = WebRenderer.running {
            VStack {
                Text("Weekly notes").padding(20).contextMenu { MenuItem("Archive") }
            }
        }
        host.step()
        let words = "[...document.querySelectorAll('*')].find((e) => e.children.length === 0 "
            + "&& e.textContent === 'Weekly notes')"
        let middle = try XCTUnwrap(place(of: words), "the view with the menu")

        touch("touchStart", [middle])
        settle(host) { self.menuShows }
        XCTAssertTrue(menuShows, "the hold opened the menu")
        touch("touchEnd", [])
        for _ in 0..<10 {
            host.step()
            WebBrowser.pause()
        }

        XCTAssertTrue(menuShows, "the menu stays as the finger that opened it lifts")
        XCTAssertEqual(
            try WebBrowser.evaluate("getComputedStyle(\(words)).userSelect", on: 0), "none",
            "the hold chooses none of the view's words")
        touch("touchStart", [Point(x: 4, y: 4)])
        touch("touchEnd", [])
        settle(host) { !self.menuShows }
        XCTAssertFalse(menuShows, "a touch beside it closes it")
        host.leave()
    }

    /// Whether a menu stands over the page.
    private var menuShows: Bool {
        (try? WebBrowser.truth("document.querySelector('.stateui-menu:popover-open') !== null", on: 0)) ?? false
    }

    /// The middle of what `found` finds, in the window.
    private func place(of found: String) throws -> Point? {
        let middle = try WebBrowser.evaluate(
            "((t) => { if (!t) return ''; const r = t.getBoundingClientRect(); "
                + "return [r.x + r.width / 2, r.y + r.height / 2].join(','); })(\(found))", on: 0) ?? ""
        let point = middle.split(separator: ",").compactMap { Double($0) }
        return point.count == 2 ? Point(x: point[0], y: point[1]) : nil
    }

    /// The browser's touch of `type`, its fingers at `points`.
    private func touch(_ type: String, _ points: [Point]) {
        WebBrowser.ask([("touch", .words(type)), ("points", .points(points))])
    }

    /// Steps the page until `done`, a few seconds at most.
    private func settle(_ host: WebRenderer, until done: () -> Bool) {
        for _ in 0..<100 {
            guard !done() else { break }
            host.step()
            WebBrowser.pause()
        }
    }
}
