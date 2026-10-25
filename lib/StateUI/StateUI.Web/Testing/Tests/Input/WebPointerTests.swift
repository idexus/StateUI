// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// The pointer as the browser gives it: a mouse comes over a view and leaves it; a finger's touch, which the browser
/// tells as a pointer coming over the view, hovers over nothing; a press is a tap only while it stays within its reach.
@MainActor
final class WebPointerTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testAFingerHoversOverNothing() throws {
        WebRenderer.shared?.leave()
        var heard: [String] = []
        let host = WebRenderer.running {
            Text("Over")
                .onPointerEntered { heard.append("entered") }
                .onPointerExited { heard.append("exited") }
                .onPointerPressed { _ in heard.append("pressed") }
        }
        host.step()
        let view = try XCTUnwrap(host.views(WebTextView.self).first)

        for (type, pointer) in [("pointerenter", "touch"), ("pointerdown", "touch"), ("pointerleave", "touch"),
                                ("pointerenter", "mouse"), ("pointerleave", "mouse")] {
            try WebBrowser.run("e.dispatchEvent(new PointerEvent('\(type)', { pointerId: 3, pointerType: '\(pointer)', "
                + "isPrimary: true }))", on: view.node)
        }
        for _ in 0..<3 { host.step() }

        XCTAssertEqual(heard, ["pressed", "entered", "exited"], "the finger's press alone, then the mouse coming and going")
    }

    /// A press that traveled as far as a drag before it lifted is no tap, though the page clicks it: a finger slid off
    /// a row and lifted beside it opens nothing; one that stayed within its reach taps; a mouse's reach is shorter.
    func testAPressThatTraveledIsNoTap() throws {
        WebRenderer.shared?.leave()
        var taps = 0
        let host = WebRenderer.running { Text("Row").onTapped { taps += 1 } }
        host.step()
        let view = try XCTUnwrap(host.views(WebTextView.self).first)

        func press(by down: Double, _ pointer: String) throws {
            try WebBrowser.run("""
                const at = (y) => ({ pointerId: 4, pointerType: '\(pointer)', isPrimary: true, button: 0,
                  clientX: 10, clientY: 10 + y, bubbles: true });
                e.dispatchEvent(new PointerEvent('pointerdown', at(0)));
                e.dispatchEvent(new PointerEvent('pointermove', at(\(down))));
                e.dispatchEvent(new PointerEvent('pointerup', at(\(down))));
                e.dispatchEvent(new MouseEvent('click', { detail: 1, bubbles: true }))
                """, on: view.node)
            for _ in 0..<3 { host.step() }
        }

        try press(by: 40, "touch")
        XCTAssertEqual(taps, 0, "a finger slid off the view: no tap")
        try press(by: 6, "touch")
        XCTAssertEqual(taps, 1, "a finger that stayed within its reach taps")
        try press(by: 6, "mouse")
        XCTAssertEqual(taps, 1, "a mouse moved past its own reach: no tap")
        try WebBrowser.run("e.dispatchEvent(new MouseEvent('click', { detail: 0, bubbles: true }))", on: view.node)
        for _ in 0..<3 { host.step() }
        XCTAssertEqual(taps, 2, "a click no pointer made - the keyboard's, a screen reader's - taps")
    }
}
