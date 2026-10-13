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

    @MainActor private static func read(_ view: WinUIView, _ what: String) -> String {
        WinUIStrings.read { stateui_winui_read(view.handle, what, $0, $1) }
    }
}
