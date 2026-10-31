// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import StateUIConformance
import XCTest

/// Buttons opening their menus by a click, with their arrow and without, and held.
private struct MenuButtonsPage: View {
    var body: some View {
        VStack {
            Button("Share").menu { MenuItem("Mail") }
            Button("More").menu { MenuItem("Mail") }.showsMenuArrow(false)
            Button("Save").onClicked {}.menu(.held) { MenuItem("Save as") }
        }
    }
}

/// A page whose bar holds a button of each way to open a menu: split, its click with its arrow and without, held.
private struct MenuActionsPage: View {
    var body: some View {
        Text("Actions").title("Actions").toolbar {
            ToolbarButton("Save").onClicked {}.menu(.split) { MenuItem("Save a copy") }
            ToolbarButton("Sort").menu { MenuItem("A to Z") }
            ToolbarButton("Share").menu { MenuItem("Mail") }.showsMenuArrow(false)
            ToolbarButton("Keep").onClicked {}.menu(.held) { MenuItem("Keep a copy") }
        }
    }
}

final class WinUIButtonMenuTests: XCTestCase {
    /// A button is WinUI's control for how it opens its menu: a DropDownButton showing its arrow, a Button opening
    /// its flyout with none, and a Button holding a held menu as its context menu, its click opening nothing.
    func testAButtonIsMadeAsItOpensItsMenu() {
        onUIThread {
            let host = WinUIRenderer.running { MenuButtonsPage() }
            let buttons = host.views(WinUIButtonView.self)

            XCTAssertEqual(buttons.map(\.menus), ["Mail", "Mail", "Save as"])
            XCTAssertEqual(buttons.map { Self.read($0, "showsMenuArrow") }, ["1", "0", "0"], "the arrow")
            XCTAssertEqual(buttons.map { Self.read($0, "opensFlyout") }, ["1", "1", "0"], "what the click opens")
        }
    }

    /// A bar's button is WinUI's control for how it opens its menu: a split one a SplitButton - its click its own,
    /// its arrow the menu's - one whose click opens it with its arrow a DropDownButton, beside WinUI's bar buttons
    /// for a click with none and for a held one.
    func testABarsButtonIsMadeAsItOpensItsMenu() throws {
        try onUIThread {
            let host = WinUIRenderer.running { MenuActionsPage() }
            let titleBar = try XCTUnwrap(host.window?.titleBar)
            let opens = (0..<4).map { place in
                WinUIStrings.read { stateui_winui_read(titleBar.handle, "action \(place) menuOpens", $0, $1) }
            }

            XCTAssertEqual(opens, ["split", "arrow", "click", "held"])
        }
    }

    @MainActor private static func read(_ view: WinUIView, _ what: String) -> String {
        WinUIStrings.read { stateui_winui_read(view.handle, what, $0, $1) }
    }
}
