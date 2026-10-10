// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
import XCTest

/// A window's place is counted from the top left of its screen's work area, across as down: a Dock standing on the
/// left moves the place it counts from.
@MainActor
final class AppKitWindowPlaceTests: XCTestCase {
    func testAPlaceIsCountedFromTheWorkAreasCorner() throws {
        let kept = AppKitWindowController.workArea
        defer { AppKitWindowController.workArea = kept }
        let area = NSRect(x: 100, y: 50, width: 1200, height: 800)
        AppKitWindowController.workArea = { _ in area }

        let host = AppKitRenderer.running { PlacedWindowPage() }
        host.runtime.pump.turn()
        let controller = try XCTUnwrap(host.roster.controllers.first)
        let window = try XCTUnwrap(controller.window)

        XCTAssertEqual(window.frame.minX, area.minX + 20, "across from the work area's left edge")
        XCTAssertEqual(window.frame.maxY, area.maxY - 30, "down from the work area's top")
        XCTAssertEqual(controller.standingValue(.x)?.number, 20)
        XCTAssertEqual(controller.standingValue(.y)?.number, 30)
    }
}

/// A page that places its window twenty points across and thirty down.
private struct PlacedWindowPage: View {
    @Environment(\.window) private var window

    var body: some View {
        Text("Placed").onCreated {
            window.x = 20
            window.y = 30
        }
    }
}
