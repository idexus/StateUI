// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// What the window lays over its pages: every layer over the whole room, the first lowest.
@MainActor
final class WebWindowTests: XCTestCase {
    /// Two layers share the room's one area, so neither is pressed into a share of it - an inspector docked over a
    /// page's own overlay keeps the height its grid gives it.
    func testEveryOverlayStandsOverTheWholeRoom() {
        let window = WebWindow()
        let (notice, inspector) = (WebLayoutView(arrangement: .single), WebLayoutView(arrangement: .single))
        defer {
            notice.detach()
            inspector.detach()
            window.close()
        }

        window.showOverlays([notice, inspector])

        for layer in [notice, inspector] {
            XCTAssertEqual(WebPage.style(of: layer.node, "grid-area"), "1 / 1 / 2 / 2", "each layer over the whole room")
        }
        XCTAssertEqual(WebPage.style(of: notice.node, "z-index"), "0", "the first lowest")
        XCTAssertEqual(WebPage.style(of: inspector.node, "z-index"), "1")
    }
}
