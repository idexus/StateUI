// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import StateUIHostConformance
import XCTest

final class WinUIPagesTests: XCTestCase {
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

    /// A sidebar taller than the window scrolls: its scroller stands in the room the pane has, shorter than what it
    /// holds.
    func testASidebarTallerThanTheWindowScrolls() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
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
