// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import StateUIConformance
import XCTest

/// A page filled by a button, declaring its menus while a state says so, which tells its window.
private struct OverlaidPage: View {
    let menus: State<Bool>
    let windows: Received<WindowSession>
    @Environment(\.window) private var window

    var body: some View {
        let (menus, windows, window) = (self.menus, self.windows, self.window)
        return Button("Beneath")
            .horizontalAlignment(.fill)
            .verticalAlignment(.fill)
            .menuBar {
                if menus.wrappedValue { Menu("File") { MenuItem("New") } }
            }
            .onCreated { windows.values.append(window) }
    }
}

/// The overlaid page under the window's sheets, each a label.
@MainActor
private func sheetsOver(_ sheets: State<[Int]>, menus: State<Bool>, windows: Received<WindowSession>) -> ModalStack {
    ModalStack(sheets.projectedValue) {
        OverlaidPage(menus: menus, windows: windows)
    } destination: { number in
        Text("Sheet \(number)")
    }
}

final class WinUIOverlayTests: XCTestCase {
    /// The window's overlay - the inspector docked in it - stands over its page and over a sheet presented after
    /// it, and a click beside what it holds goes on to the page; closed, it is gone.
    func testTheWindowsOverlayStandsOverItsPageLettingAClickBesideItThrough() throws {
        try onUIThread {
            let (sheets, menus, windows) = (State(wrappedValue: [Int]()), State(wrappedValue: false), Received<WindowSession>())
            let host = WinUIRenderer.running { sheetsOver(sheets, menus: menus, windows: windows) }
            let window = try XCTUnwrap(host.window)
            let session = try XCTUnwrap(windows.values.last)
            defer { Inspector.close(in: session) }
            let beneath = try XCTUnwrap(host.views(WinUIButtonView.self).first)
            let size = beneath.frame
            XCTAssertTrue(beneath.reaches(size.width / 2, size.height - 20), "nothing over the page yet")

            Inspector.open(in: session)
            host.settle { !window.overlays.isEmpty }
            let overlay = try XCTUnwrap((host.runtime.tree.root?.first(type: .overlay)?.native as? WinUIElement)?.view)
            XCTAssertTrue(window.overlays.elementsEqual([overlay], by: ===))
            host.layOut()
            XCTAssertEqual(overlay.frame.width, size.width, "laid over the page, as wide")
            XCTAssertFalse(beneath.reaches(size.width / 2, size.height - 20), "the folded inspector along the bottom")
            XCTAssertTrue(overlay.reaches(size.width / 2, size.height - 20))
            XCTAssertTrue(beneath.reaches(size.width / 2, 20), "a click beside it reaches the page")

            sheets.wrappedValue = [1]
            host.settle { stateui_winui_window_sheets(window.handle) == 1 }
            XCTAssertTrue(overlay.reaches(size.width / 2, size.height - 20), "over the sheet presented after it")

            Inspector.close(in: session)
            host.settle { window.overlays.isEmpty }
            XCTAssertTrue(window.overlays.isEmpty)
            XCTAssertFalse(overlay.reaches(size.width / 2, size.height - 20), "taken out of the window")
        }
    }

    /// The window's layers over its rows - its sheets, its overlay - are no row's own: the menu bar coming to stand
    /// beneath the chrome takes neither away.
    func testTheChromeStandingAgainLeavesTheSheetsAndTheOverlay() throws {
        try onUIThread {
            let (sheets, menus, windows) = (State(wrappedValue: [1]), State(wrappedValue: false), Received<WindowSession>())
            let host = WinUIRenderer.running { sheetsOver(sheets, menus: menus, windows: windows) }
            let window = try XCTUnwrap(host.window)
            let session = try XCTUnwrap(windows.values.last)
            defer { Inspector.close(in: session) }
            Inspector.open(in: session)
            host.settle { !window.overlays.isEmpty && stateui_winui_window_sheets(window.handle) == 1 }
            XCTAssertEqual(stateui_winui_window_sheets(window.handle), 1)

            menus.wrappedValue = true
            host.settle { window.menuBarStands }
            XCTAssertTrue(window.menuBarStands)
            XCTAssertEqual(stateui_winui_window_sheets(window.handle), 1, "the sheet stays")
            let overlay = try XCTUnwrap(window.overlays.first)
            host.layOut()
            XCTAssertTrue(overlay.reaches(overlay.frame.width / 2, overlay.frame.height - 20), "the overlay stays")
        }
    }
}
