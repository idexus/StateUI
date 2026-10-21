// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
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
            notice.release()
            inspector.release()
            window.close()
        }

        window.showOverlays([notice, inspector])

        for layer in [notice, inspector] {
            XCTAssertEqual(WebPage.style(of: layer.node, "grid-area"), "1 / 1 / 2 / 2", "each layer over the whole room")
        }
        XCTAssertEqual(WebPage.style(of: notice.node, "z-index"), "0", "the first lowest")
        XCTAssertEqual(WebPage.style(of: inspector.node, "z-index"), "1")
    }

    /// THE PAGE UNDER THE WINDOW WEARS ITS COLOR where the window is one opaque color - what Safari takes above
    /// the page and around its bars - and none where it is translucent, a blur, or the platform's own.
    func testThePageWearsTheWindowsColorWhereItIsOneOpaqueColor() {
        let opaque = HostValue.color(red: 42, green: 33, blue: 84, alpha: 255)
        XCTAssertEqual(WebWindowController.pageColor(HostMaterial(opaque)), "rgb(42 33 84 / 1)")
        let translucent = HostValue.color(red: 42, green: 33, blue: 84, alpha: 128)
        XCTAssertNil(WebWindowController.pageColor(HostMaterial(translucent)), "the page under it would show through")
        XCTAssertNil(WebWindowController.pageColor(HostMaterial(nil)), "the platform's own window")
    }
}
