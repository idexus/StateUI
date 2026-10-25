// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// The pointer as the browser gives it: a mouse comes over a view and leaves it; a finger's touch, which the browser
/// tells as a pointer coming over the view, hovers over nothing.
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
}
