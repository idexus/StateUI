// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import StateUIHostConformance
import XCTest

final class WinUIPagesTests: XCTestCase {
    /// The top page names the window, and the way back is the chrome's own back button; it pops the page.
    func testTheWindowsChromeCarriesTheTopPageAndTheWayBack() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = WinUIRenderer.running {
                NavigationStack(path.projectedValue) {
                    TitledPage(title: "Root")
                } destination: { number in
                    TitledPage(title: "Detail \(number)")
                }
            }
            let window = try XCTUnwrap(host.window)
            XCTAssertEqual(window.titleBar.chrome.title, "Root")
            XCTAssertNil(window.titleBar.chrome.back)
            XCTAssertFalse(host.goBack(), "no way back from the root")

            path.wrappedValue.append(7)
            host.runtime.pump.turn()
            XCTAssertEqual(window.titleBar.chrome.title, "Detail 7")
            XCTAssertEqual(window.titleBar.chrome.back?.title, "Back")
            let navigation = try XCTUnwrap(host.views(WinUINavigationView.self).first)
            XCTAssertEqual(navigation.heldViews().count, 1, "the top page alone, under the window's chrome")

            window.titleBar.chose(-1)
            XCTAssertEqual(path.wrappedValue, [], "the chrome's back button pops the page")
            XCTAssertEqual(window.titleBar.chrome.title, "Root")
        }
    }

    /// A push: the root navigates from and disappears, then the pushed page appears and is navigated to; a pop the
    /// other way - every phase rendered before the next is heard.
    func testAPushAndAPopAreHeardByThePagesInOrder() {
        onUIThread {
            let path = State(wrappedValue: [Int]())
            let log = Received<String>()
            let host = WinUIRenderer.running {
                NavigationStack(path.projectedValue) {
                    TitledPage(title: "Root", log: log)
                } destination: { _ in
                    TitledPage(title: "Pushed", log: log)
                }
            }
            XCTAssertEqual(log.values, ["Root appearing", "Root navigatedTo"])

            log.values = []
            path.wrappedValue.append(1)
            host.runtime.pump.turn()
            XCTAssertEqual(log.values, [
                "Root navigatingFrom", "Root disappearing", "Root navigatedFrom",
                "Pushed appearing", "Pushed navigatedTo",
            ])

            // The popped page has left the tree, and a page that left hears nothing more.
            log.values = []
            XCTAssertTrue(host.goBack())
            XCTAssertEqual(log.values, ["Root appearing", "Root navigatedTo"])
        }
    }

    /// A window wide enough for both panes opens with its sidebar shown beside the detail and settles its binding;
    /// the chrome's toggle then hides it, and the binding hears the user.
    func testAWideWindowOpensWithItsSidebarAndTheUserMayHideIt() throws {
        try onUIThread {
            let open = State(wrappedValue: false)
            let log = Received<String>()
            let host = WinUIRenderer.running {
                SplitView(open.projectedValue) {
                    TitledPage(title: "Menu", log: log)
                } detail: {
                    TitledPage(title: "Home")
                }
            }
            let split = try XCTUnwrap(host.views(WinUISplitView.self).first)
            let window = try XCTUnwrap(host.window)
            host.settle { open.wrappedValue }
            XCTAssertTrue(split.isPresented)
            XCTAssertTrue(open.wrappedValue, "the binding settles on what the window shows")
            XCTAssertEqual(log.values, ["Menu appearing"])
            XCTAssertNotNil(window.titleBar.chrome.sidebarToggle)
            XCTAssertEqual(window.titleBar.chrome.title, "Home", "the detail names the window")

            window.titleBar.chose(-2)
            XCTAssertFalse(split.isPresented)
            XCTAssertFalse(open.wrappedValue)
            XCTAssertEqual(log.values, ["Menu appearing", "Menu disappearing"])
        }
    }

    /// A detail page beside the open sidebar is laid out in the room beside it, however the sidebar opened: a
    /// scroller's content there is as wide as the scroller.
    func testADetailBesideTheSidebarTakesTheRoomBesideIt() throws {
        try onUIThread {
            let open = State(wrappedValue: false)
            let host = WinUIRenderer.running {
                SplitView(open.projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    ScrollView {
                        VStack { HStack { Label("row") } }
                    }
                }
            }
            let window = try XCTUnwrap(host.window)
            host.settle { open.wrappedValue }
            window.titleBar.chose(-2)
            host.runtime.pump.turn()
            window.titleBar.chose(-2)
            host.runtime.pump.turn()
            host.layOut()

            let scroller = try XCTUnwrap(host.views(WinUIScrollView.self).first)
            let row = try XCTUnwrap(host.views(WinUIStackView.self).last)
            XCTAssertTrue(open.wrappedValue)
            XCTAssertGreaterThan(scroller.frame.width, 0)
            XCTAssertEqual(row.frame.width, scroller.frame.width, "the row across the scroller's content")
        }
    }

    /// A tabbed view on the window's page path shows its tabs in the window's row beneath its chrome, and none on
    /// its content; choosing in the row is the user choosing, and renames the window at once.
    func testAWindowsTabbedViewSelectsFromTheRowBeneathItsChrome() throws {
        try onUIThread {
            let tab = State(wrappedValue: 0)
            let host = WinUIRenderer.running {
                TabbedView([0, 1]) { number in
                    TitledPage(title: "Tab \(number)")
                }
                .selection(tab.projectedValue)
            }
            let window = try XCTUnwrap(host.window)
            let tabs = try XCTUnwrap(host.views(WinUITabbedView.self).first)
            XCTAssertTrue(tabs.tabsShownByWindow)
            XCTAssertTrue(window.tabsStandInWindow)
            XCTAssertEqual(window.tabRow.titles, ["Tab 0", "Tab 1"])
            XCTAssertEqual(tabs.heldViews().count, 1, "the page alone, its tabs in the window's row")
            XCTAssertEqual(window.titleBar.chrome.title, "Tab 0")

            window.tabRow.chose(1)
            XCTAssertEqual(tab.wrappedValue, 1)
            XCTAssertEqual(window.titleBar.chrome.title, "Tab 1")
        }
    }

    /// A tabbed view in a split view's detail stands its tabs across the detail, beside the sidebar.
    func testATabbedDetailStandsItsTabsAcrossTheDetail() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    TabbedView([0, 1]) { number in TitledPage(title: "Tab \(number)") }
                }
            }
            let window = try XCTUnwrap(host.window)
            let split = try XCTUnwrap(host.views(WinUISplitView.self).first)
            XCTAssertFalse(window.tabsStandInWindow)
            XCTAssertTrue(split.detailRow === window.tabRow)
        }
    }

    /// The visible page's actions stand on the chrome in their priority's order, the overflow's last; choosing one
    /// runs its handler, and one that cannot be chosen runs nothing.
    func testThePagesActionsFollowTheirOrderAndPriorityOnTheChrome() throws {
        try onUIThread {
            let heard = Received<String>()
            let host = WinUIRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Notes", actions: [
                        ToolbarItem("Delete").placement(.overflow).onClicked { heard.values.append("delete") },
                        ToolbarItem("Save").priority(1).onClicked { heard.values.append("save") },
                        ToolbarItem("Add").priority(0).isEnabled(false).onClicked { heard.values.append("add") },
                    ])
                } destination: { _ in
                    TitledPage(title: "Note")
                }
            }
            let chrome = try XCTUnwrap(host.window).titleBar
            XCTAssertEqual(chrome.chrome.actions.map(\.title), ["Add", "Save"])
            XCTAssertEqual(chrome.chrome.overflow.map(\.title), ["Delete"])

            for index in 0..<3 { chrome.chose(index) }
            host.runtime.pump.turn()
            XCTAssertEqual(heard.values, ["save", "delete"])
        }
    }

    /// A page's title view stands at the chrome's centre; a page pushed over it, with none, leaves it; back, and it
    /// stands there again.
    func testAPagesTitleViewStandsAtTheChromesCentre() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = WinUIRenderer.running {
                NavigationStack(path.projectedValue) {
                    SearchingPage()
                } destination: { _ in
                    TitledPage(title: "Result")
                }
            }
            let chrome = try XCTUnwrap(host.window).titleBar
            let field = try XCTUnwrap(host.views(WinUITextFieldView.self).first)
            XCTAssertTrue(chrome.chrome.center === field)

            path.wrappedValue = [1]
            host.runtime.pump.turn()
            XCTAssertNil(chrome.chrome.center)
            XCTAssertEqual(chrome.chrome.title, "Result")

            XCTAssertTrue(host.goBack())
            host.runtime.pump.turn()
            XCTAssertTrue(chrome.chrome.center === field)
        }
    }

    /// A page that hides its navigation bar keeps the way back and its actions off the chrome.
    func testAPageWithoutANavigationBarKeepsItsWayBackAndActionsOffTheChrome() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                NavigationStack(State(wrappedValue: [1]).projectedValue) {
                    TitledPage(title: "Root")
                } destination: { _ in
                    TitledPage(title: "Bare", actions: [ToolbarItem("Save")], hidesBar: true)
                }
            }
            let chrome = try XCTUnwrap(host.window).titleBar.chrome
            XCTAssertNil(chrome.back)
            XCTAssertTrue(chrome.actions.isEmpty)
        }
    }
}

/// A page with a title, maybe a log of its phases, the actions it puts on the window's chrome, and whether it hides
/// its navigation bar.
private struct TitledPage: ContentView {
    let title: String
    var log: Received<String>? = nil
    var actions: [ToolbarItem] = []
    var hidesBar = false

    @Environment private var page: PageSession

    var content: any View {
        let log = self.log
        let title = self.title
        let page = self.page

        return Label(title)
            .onCreated {
                page.title = title
                page.toolbarItems = actions
                if hidesBar { page.hasNavigationBar = false }
            }
            .onChanged(page.phase) { log?.values.append("\(title) \(page.phase)") }
    }
}

/// A page whose title view is a search field.
private struct SearchingPage: ContentView {
    @Environment private var page: PageSession
    @State private var query = ""

    var content: any View {
        let page = self.page
        let query = $query
        return Label("Results").onCreated {
            page.title = "Search"
            page.titleView = TextField(query).placeholder("Search")
        }
    }
}
