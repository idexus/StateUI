// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import StateUIConformance
import XCTest

final class WinUIPagesTests: XCTestCase {
    /// A detail page beside the open sidebar is laid out in the room beside it, however the sidebar opened: a
    /// scroller's content there is as wide as the scroller.
    func testADetailBesideTheSidebarTakesTheRoomBesideIt() throws {
        try onUIThread {
            let open = State(wrappedValue: false)
            let host = WinUIRenderer.running(room: WinUITestHost.wideRoom) {
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

    /// The sidebar's page stands in the pane's height from the first start: a footer under a scroller of many rows
    /// stands inside the window. WinUI lays the pane's content out once in a row sized to what it holds, before the
    /// relay gives that row the pane's height; a StateUI layout inside kept the places of that first layout, and the
    /// footer stood below the window until the pane was closed and opened again.
    func testTheSidebarsFooterStandsInTheWindowFromTheFirstStart() throws {
        try onUIThread {
            let open = State(wrappedValue: true)
            let host = WinUIRenderer.running(room: WinUITestHost.wideRoom) {
                SplitView(open.projectedValue) {
                    Grid {
                        ScrollView {
                            VStack { ForEach(0..<60, id: \.self) { Label("row \($0)") } }
                        }
                        Label("footer").gridRow(1)
                    }
                    .rows(.fill, .auto)
                } detail: {
                    Label("detail")
                }
            }
            for _ in 0..<20 { host.step() }
            host.layOut()

            let split = try XCTUnwrap(host.views(WinUISplitView.self).first)
            let footer = try XCTUnwrap(host.views(WinUILabelView.self).first { $0.text == "footer" })
            XCTAssertGreaterThan(footer.frame.height, 0)
            XCTAssertLessThanOrEqual(
                footer.origin.y + footer.frame.height, split.origin.y + split.frame.height + 1,
                "the footer stands below the window")
        }
    }

    /// A row of tabs marks the tab the view shows as the tabs change, and what the program changes is no choice of the
    /// user's.
    func testTheRowMarksTheTabShownAsTheTabsChange() throws {
        try onUIThread {
            let tabs = State(wrappedValue: [0, 1, 2])
            let tab = State(wrappedValue: 2)
            let host = WinUIRenderer.running {
                TabbedView(tabs.wrappedValue) { number in Label("Tab \(number)") }.selection(tab.projectedValue)
            }
            let tabbed = try XCTUnwrap(host.views(WinUITabbedView.self).first)
            let row: WinUIView = tabbed.tabsShownByWindow ? try XCTUnwrap(host.window).tabRow : tabbed.row
            XCTAssertEqual(Self.selected(row), 2)

            tabs.wrappedValue = [0, 1]
            host.runtime.pump.turn()
            let now = try XCTUnwrap(host.views(WinUITabbedView.self).first)
            XCTAssertEqual(now.titles.count, 2)
            XCTAssertEqual(Self.selected(row), now.shownIndex, "the row marks the tab shown")
            XCTAssertEqual(tab.wrappedValue, 2, "and no choice of the user's heard")
        }
    }

    /// Tabs pushed onto a stack are its last place and name the window by their own title, in the chrome and in the
    /// window's own name - never by what they show: their pages name their tabs alone.
    func testTabsOnAStackNameTheWindowByTheirOwnTitle() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = WinUIRenderer.running {
                NavigationStack(path.projectedValue) {
                    TitledPage(title: "Items and Cards")
                } destination: { _ in
                    TabbedView([1, 2]) { number in TitledPage(title: "Example \(number)") }.title("ItemsView")
                }
            }
            let window = try XCTUnwrap(host.window)
            host.settle { Self.words(window.titleBar, "title") == "Items and Cards" }

            path.wrappedValue = [1]
            host.settle { host.views(WinUITabbedView.self).first?.titles == ["Example 1", "Example 2"] }
            XCTAssertEqual(host.views(WinUITabbedView.self).first?.titles, ["Example 1", "Example 2"], "pushed")
            XCTAssertEqual(Self.words(window.titleBar, "title"), "ItemsView", "the chrome's title")
            var bytes = [CChar](repeating: 0, count: 64)
            let length = stateui_winui_window_system_title(window.handle, &bytes, Int32(bytes.count))
            XCTAssertEqual(
                String(decoding: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self),
                "ItemsView", "the window's own name")
        }
    }

    /// What the relay reads of `view` as `what`.
    @MainActor
    private static func words(_ view: WinUIView, _ what: String) -> String {
        var bytes = [CChar](repeating: 0, count: 128)
        let length = stateui_winui_read(view.handle, what, &bytes, Int32(bytes.count))
        return String(decoding: bytes.prefix(Int(max(length, 0))).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// The place of the tab a row marks; -1 for none.
    @MainActor
    private static func selected(_ row: WinUIView) -> Int {
        var bytes = [CChar](repeating: 0, count: 16)
        let length = stateui_winui_read(row.handle, "selected", &bytes, Int32(bytes.count))
        let words = String(decoding: bytes.prefix(Int(max(length, 0))).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return Double(words).map { Int($0) } ?? -1
    }

    /// Words on a bar the tree paints stand light on a dark bar and dark on a light one, where the tree writes no
    /// colour for them (`BandWords`) - the title, the way back and the actions alike.
    func testWordsOnAPaintedBarFollowHowDarkItIs() throws {
        try onUIThread {
            let dark = State(wrappedValue: true)
            let (navy, yellow) = (Color(red: 0, green: 0, blue: 128), Color(red: 255, green: 230, blue: 0))
            let host = WinUIRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    Label("Root")
                } destination: { _ in Label("Pushed") }
                    .barBackgroundColor(dark.wrappedValue ? navy : yellow)
            }
            let bar = try XCTUnwrap(host.window).titleBar
            XCTAssertEqual(stateui_winui_title_bar_words(bar.handle), 1, "light on navy")

            dark.wrappedValue = false
            host.settle { stateui_winui_title_bar_words(bar.handle) == 2 }
            XCTAssertEqual(stateui_winui_title_bar_words(bar.handle), 2, "dark on yellow, once the colour travelled")
        }
    }

    /// The chrome keeps the window's own buttons their room once, at the scale the window stands at: WinUI's title
    /// bar keeps it in pixels as though they were DIPs, which at 200% stands its actions a caption's width short of
    /// the bar's end.
    func testTheChromeKeepsTheCaptionButtonsTheirRoomOnce() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Home", actions: [ToolbarItem("Inspector")])
                } destination: { _ in Label("Pushed") }
            }
            let bar = try XCTUnwrap(host.window).titleBar
            var (kept, room) = (-1.0, 0.0)
            host.settle {
                stateui_winui_title_bar_caption_room(bar.handle, &kept, &room)
                return kept >= 0 && room > 0
            }
            XCTAssertGreaterThan(room, 0, "the window has its own buttons")
            XCTAssertEqual(kept, room, accuracy: 0.5, "the room kept is theirs")
        }
    }

    /// A sidebar taller than the window scrolls: its scroller stands in the room the pane has, shorter than what it
    /// holds.
    func testASidebarTallerThanTheWindowScrolls() throws {
        try onUIThread {
            let host = WinUIRenderer.running(room: WinUITestHost.wideRoom) {
                SplitView(State(wrappedValue: true).projectedValue) {
                    ScrollView {
                        VStack { ForEach(Array(0..<100), id: \.self) { number in Label("Row \(number)") } }
                    }
                } detail: {
                    Label("Detail")
                }
            }
            host.layOut()
            let scroller = try XCTUnwrap(host.views(WinUIScrollView.self).first)
            let rows = try XCTUnwrap(host.views(WinUIStackView.self).first)
            host.settle { scroller.frame.height > 0 && scroller.frame.height < rows.frame.height }

            XCTAssertGreaterThan(scroller.frame.height, 0)
            XCTAssertLessThan(scroller.frame.height, rows.frame.height, "the rows run past the scroller: it scrolls")
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
