// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

/// A page writing its menus into its session - File, with a submenu of what a state lists, and Edit - and saying
/// what the user chose.
private struct MenusPage: ContentView {
    let heard: Received<String>
    @State private var recent = ["a.txt"]
    @Environment private var page: PageSession

    private var menus: [Menu] {
        let heard = heard
        return [
            Menu("File") {
                MenuItem("New").onClicked { heard.values.append("new") }
                MenuSeparator()
                Menu("Recent") {
                    ForEach(recent, id: \.self) { file in
                        MenuItem(file).onClicked { heard.values.append("open \(file)") }
                    }
                }
            },
            Menu("Edit") {
                MenuItem("Undo").isEnabled(false)
            },
        ]
    }

    var content: any View {
        let page = page
        let recent = $recent
        return VStack {
            Button("More").onClicked { recent.wrappedValue.append("b.txt") }
        }
        .onCreated { page.menuBar = menus }
        .onChanged(recent.wrappedValue) { page.menuBar = menus }
    }
}

final class WinUIMenuBarTests: XCTestCase {
    /// The visible page's menus stand on the window's menu bar beneath the chrome, each with its entries; choosing
    /// an item runs its handler.
    func testThePagesMenusStandOnTheWindowsMenuBar() throws {
        try onUIThread {
            let heard = Received<String>()
            let host = WinUIRenderer.running { MenusPage(heard: heard) }
            let window = try XCTUnwrap(host.window)
            XCTAssertTrue(window.menuBarStands)
            XCTAssertEqual(window.menuBar.menus, "File[New;-;Recent[a.txt]];Edit[!Undo]")

            stateui_winui_menus_choose(window.menuBar.handle, 1)
            host.settle { heard.values == ["open a.txt"] }
            stateui_winui_menus_choose(window.menuBar.handle, 0)
            host.settle { heard.values.count == 2 }
            XCTAssertEqual(heard.values, ["open a.txt", "new"])
        }
    }

    /// Menus the page writes again show what they say now.
    func testTheBarShowsTheMenusThePageWritesAgain() throws {
        try onUIThread {
            let host = WinUIRenderer.running { MenusPage(heard: Received()) }
            let window = try XCTUnwrap(host.window)

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { window.menuBar.menus == "File[New;-;Recent[a.txt;b.txt]];Edit[!Undo]" }
            XCTAssertEqual(window.menuBar.menus, "File[New;-;Recent[a.txt;b.txt]];Edit[!Undo]")
        }
    }

    /// The bar follows the visible page: a page with no menus leaves none standing, and back, its menus stand again.
    func testTheBarFollowsTheVisiblePage() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = WinUIRenderer.running {
                NavigationStack(path.projectedValue) {
                    MenusPage(heard: Received())
                } destination: { _ in
                    Label("Note")
                }
            }
            let window = try XCTUnwrap(host.window)
            XCTAssertTrue(window.menuBarStands)

            path.wrappedValue = [1]
            host.pump()
            XCTAssertFalse(window.menuBarStands, "a page with no menus")
            XCTAssertEqual(window.menuBar.menus, "")

            path.wrappedValue = []
            host.pump()
            XCTAssertTrue(window.menuBarStands, "back on the page with menus")
            XCTAssertEqual(window.menuBar.menus, "File[New;-;Recent[a.txt]];Edit[!Undo]")
        }
    }
}
