// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

extension OverlayKey {
    fileprivate static let notice = OverlayKey("notice")
}

/// A page filled by a button, presenting its sheets from one state, writing its menus from another and laying a
/// notice over its window from a third, which tells its scene.
private struct OverlaidPage: ContentView {
    let sheets: State<[Int]>
    let menus: State<Bool>
    let scenes: Received<SceneSession>
    var notice = State(wrappedValue: false)

    @Environment private var window: WindowSession
    @Environment private var scene: SceneSession
    @Environment private var page: PageSession

    var content: any View {
        let (sheets, menus, scenes, notice) = (self.sheets, self.menus, self.scenes, self.notice)
        let (window, scene, page) = (self.window, self.scene, self.page)
        return Button("Beneath")
            .horizontalAlignment(.fill)
            .verticalAlignment(.fill)
            .onCreated {
                scenes.values.append(scene)
                window.modalStack = ModalStack(sheets.projectedValue) { number in Label("Sheet \(number)") }
            }
            .onChanged(menus.wrappedValue) {
                page.menuBar = menus.wrappedValue ? [Menu("File") { MenuItem("New") }] : []
            }
            .onChanged(notice.wrappedValue) {
                window.overlays[.notice] = notice.wrappedValue
                    ? Label("Offline").horizontalAlignment(.center).verticalAlignment(.start) : nil
            }
    }
}

final class WinUIOverlayTests: XCTestCase {
    /// The application's own overlay stands over the page and over a sheet presented after it, where its alignments
    /// put it; a click beside it reaches the page, and nil takes it away.
    func testTheApplicationsOverlayStandsOverThePageAndItsSheets() throws {
        try onUIThread {
            let (sheets, notice) = (State(wrappedValue: [Int]()), State(wrappedValue: false))
            let host = WinUIRenderer.running {
                OverlaidPage(sheets: sheets, menus: State(wrappedValue: false), scenes: Received(), notice: notice)
            }
            let window = try XCTUnwrap(host.window)
            let beneath = try XCTUnwrap(host.views(WinUIButtonView.self).first)
            XCTAssertNil(window.overlay)

            notice.wrappedValue = true
            host.settle { window.overlay != nil }
            host.layOut()
            let words = try XCTUnwrap(host.views(WinUILabelView.self).first { $0.text == "Offline" })
            let size = beneath.frame
            XCTAssertEqual(words.frame.y, 0, "at the top, where its alignment puts it")
            XCTAssertTrue(words.reaches(words.frame.width / 2, words.frame.height / 2))
            XCTAssertTrue(beneath.reaches(size.width / 2, size.height / 2), "a click beside it reaches the page")

            sheets.wrappedValue = [1]
            host.settle { stateui_winui_window_sheets(window.handle) == 1 }
            XCTAssertTrue(words.reaches(words.frame.width / 2, words.frame.height / 2), "over the sheet")

            notice.wrappedValue = false
            host.settle { window.overlay == nil }
            XCTAssertNil(window.overlay)
        }
    }

    /// The window's overlay - the inspector docked in it - stands over its page and over a sheet presented after
    /// it, and a click beside what it holds goes on to the page; closed, it is gone.
    func testTheWindowsOverlayStandsOverItsPageLettingAClickBesideItThrough() throws {
        try onUIThread {
            let (sheets, menus, scenes) = (State(wrappedValue: [Int]()), State(wrappedValue: false), Received<SceneSession>())
            let host = WinUIRenderer.running { OverlaidPage(sheets: sheets, menus: menus, scenes: scenes) }
            let window = try XCTUnwrap(host.window)
            let scene = try XCTUnwrap(scenes.values.last)
            defer { Inspector.close(in: scene) }
            let beneath = try XCTUnwrap(host.views(WinUIButtonView.self).first)
            let size = beneath.frame
            XCTAssertTrue(beneath.reaches(size.width / 2, size.height - 20), "nothing over the page yet")

            Inspector.open(in: scene)
            host.settle { window.overlay != nil }
            let overlay = try XCTUnwrap((host.tree.root?.first(type: .overlay)?.native as? WinUIElement)?.view)
            XCTAssertTrue(window.overlay === overlay)
            host.layOut()
            XCTAssertEqual(overlay.frame.width, size.width, "laid over the page, as wide")
            XCTAssertFalse(beneath.reaches(size.width / 2, size.height - 20), "the folded inspector along the bottom")
            XCTAssertTrue(overlay.reaches(size.width / 2, size.height - 20))
            XCTAssertTrue(beneath.reaches(size.width / 2, 20), "a click beside it reaches the page")

            sheets.wrappedValue = [1]
            host.settle { stateui_winui_window_sheets(window.handle) == 1 }
            XCTAssertTrue(overlay.reaches(size.width / 2, size.height - 20), "over the sheet presented after it")

            Inspector.close(in: scene)
            host.settle { window.overlay == nil }
            XCTAssertNil(window.overlay)
            XCTAssertFalse(overlay.reaches(size.width / 2, size.height - 20), "taken out of the window")
        }
    }

    /// The window's layers over its rows - its sheets, its overlay - are no row's own: the menu bar coming to stand
    /// beneath the chrome takes neither away.
    func testTheChromeStandingAgainLeavesTheSheetsAndTheOverlay() throws {
        try onUIThread {
            let (sheets, menus, scenes) = (State(wrappedValue: [1]), State(wrappedValue: false), Received<SceneSession>())
            let host = WinUIRenderer.running { OverlaidPage(sheets: sheets, menus: menus, scenes: scenes) }
            let window = try XCTUnwrap(host.window)
            let scene = try XCTUnwrap(scenes.values.last)
            defer { Inspector.close(in: scene) }
            Inspector.open(in: scene)
            host.settle { window.overlay != nil && stateui_winui_window_sheets(window.handle) == 1 }
            XCTAssertEqual(stateui_winui_window_sheets(window.handle), 1)

            menus.wrappedValue = true
            host.settle { window.menuBarStands }
            XCTAssertTrue(window.menuBarStands)
            XCTAssertEqual(stateui_winui_window_sheets(window.handle), 1, "the sheet stays")
            let overlay = try XCTUnwrap(window.overlay)
            host.layOut()
            XCTAssertTrue(overlay.reaches(overlay.frame.width / 2, overlay.frame.height - 20), "the overlay stays")
        }
    }
}
