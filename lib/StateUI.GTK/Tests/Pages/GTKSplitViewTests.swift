// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
import StateUIHostConformance
import XCTest

final class GTKSplitViewTests: XCTestCase {
    /// Each pane is a page in a frame of its own; a window wide enough for both opens with the sidebar shown, and
    /// the binding hears it.
    func testAWideWindowOpensWithItsSidebarBesideTheDetail() throws {
        try onUIThread {
            let open = State(wrappedValue: false)
            let host = GTKRenderer.running {
                SplitView(open.projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    TitledPage(title: "Detail")
                }
            }
            let split = try XCTUnwrap(host.views(GTKSplitView.self).first)
            XCTAssertEqual(split.sidebarFrame?.chrome.title, "Menu")
            XCTAssertEqual(split.detailFrame?.chrome.title, "Detail")
            XCTAssertEqual(host.windowTitle, "Detail")

            host.settle { open.wrappedValue }
            XCTAssertTrue(split.isPresented, "shown beside the detail")
            XCTAssertTrue(open.wrappedValue, "and the binding heard it")
            XCTAssertFalse(split.isCollapsed)
        }
    }

    /// The detail's header bar carries the sidebar's toggle, pressed in while it shows; the user hides the sidebar
    /// with it and the binding hears the user, then shows it again.
    func testTheDetailsToggleHidesAndShowsTheSidebar() throws {
        try onUIThread {
            let open = State(wrappedValue: true)
            let host = GTKRenderer.running {
                SplitView(open.projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    TitledPage(title: "Detail")
                }
            }
            let split = try XCTUnwrap(host.views(GTKSplitView.self).first)
            let toggle = try XCTUnwrap(split.detailFrame?.sidebarToggle)
            XCTAssertEqual(gtk_toggle_button_get_active(toggle.widget.of(GtkToggleButton.self)), 1)

            toggle.click()
            XCTAssertFalse(split.isPresented)
            XCTAssertFalse(open.wrappedValue)
            XCTAssertEqual(gtk_toggle_button_get_active(toggle.widget.of(GtkToggleButton.self)), 0)

            toggle.click()
            XCTAssertTrue(split.isPresented)
            XCTAssertTrue(open.wrappedValue)
        }
    }

    /// A stack in the detail carries its own pages' header bars, the sidebar's toggle on the top page's.
    func testAStackInTheDetailCarriesTheToggleOnItsTopPage() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = GTKRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    NavigationStack(path.projectedValue) {
                        TitledPage(title: "Home")
                    } destination: { number in
                        TitledPage(title: "Page \(number)")
                    }
                }
            }
            let split = try XCTUnwrap(host.views(GTKSplitView.self).first)
            let navigation = try XCTUnwrap(host.views(GTKNavigationView.self).first)
            XCTAssertNil(split.detailFrame, "the stack carries its pages' frames")
            XCTAssertNotNil(navigation.frames.last?.sidebarToggle)

            path.wrappedValue = [2]
            host.pump.turn()
            XCTAssertEqual(navigation.frames.map(\.chrome.title), ["Home", "Page 2"])
            XCTAssertNotNil(navigation.frames.last?.sidebarToggle)
            XCTAssertEqual(host.windowTitle, "Page 2")
        }
    }
}

final class GTKTabbedViewTests: XCTestCase {
    /// A tabbed view shown by the window stands in a frame whose header bar holds its switcher; the user's choice
    /// reaches the selection, the pages hear it, and the header bar carries the chosen tab's actions.
    func testTheSwitcherChoosesATabInTheHeaderBar() throws {
        try onUIThread {
            let tab = State(wrappedValue: "one")
            let log = Received<String>()
            let host = GTKRenderer.running {
                TabbedView(["one", "two"]) { name in
                    TitledPage(
                        title: name == "one" ? "One" : "Two", log: log,
                        actions: name == "two" ? [ToolbarItem("Share")] : [])
                }
                .selection(tab.projectedValue)
            }
            let tabs = try XCTUnwrap(host.views(GTKTabbedView.self).first)
            let frame = try XCTUnwrap(host.window?.pageFrame)
            XCTAssertTrue(frame.chrome.titleView === tabs.switcher)
            XCTAssertTrue(adw_header_bar_get_title_widget(frame.header.opaque) == tabs.switcher.widget)

            log.values = []
            tabs.selectByUser(1)
            host.pump.turn()
            XCTAssertEqual(tab.wrappedValue, "two")
            XCTAssertEqual(log.values, ["One disappearing", "Two appearing"])
            XCTAssertEqual(frame.buttons.map(\.text), ["Share"])
        }
    }

    /// A tabbed view pushed on a stack is a page of it, in a frame whose header bar holds its switcher.
    func testATabbedViewPushedOnAStackStandsInAFrame() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                NavigationStack(State(wrappedValue: [1]).projectedValue) {
                    TitledPage(title: "Home")
                } destination: { _ in
                    TabbedView(["a", "b"]) { name in TitledPage(title: name) }
                }
            }
            let tabs = try XCTUnwrap(host.views(GTKTabbedView.self).first)
            let navigation = try XCTUnwrap(host.views(GTKNavigationView.self).first)
            XCTAssertTrue(navigation.frames.last?.chrome.titleView === tabs.switcher)
        }
    }
}
