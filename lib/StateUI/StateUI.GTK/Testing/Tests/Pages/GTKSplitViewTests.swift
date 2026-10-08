// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import StateUIConformance
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

    /// A sidebar beside the detail lets the window through its pane, shaded a breath where the split view says no
    /// material; under a material of its own the pane is clear.
    func testASidebarBesideTheDetailLetsTheWindowThrough() throws {
        try onUIThread {
            let material = State(wrappedValue: Material(light: nil, dark: nil))
            let host = GTKRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    TitledPage(title: "Detail")
                }
                .sidebarBackground(material.projectedValue)
            }
            let split = try XCTUnwrap(host.views(GTKSplitView.self).first)
            XCTAssertFalse(split.isCollapsed)
            XCTAssertNotEqual(gtk_widget_has_css_class(split.splitWidgetForTesting, "stateui-sidebar-shaded"), 0)

            material.wrappedValue = .color(Color("#512BD4"))
            host.settle { gtk_widget_has_css_class(split.splitWidgetForTesting, "stateui-sidebar-clear") != 0 }
            XCTAssertNotEqual(gtk_widget_has_css_class(split.splitWidgetForTesting, "stateui-sidebar-clear"), 0)
        }
    }

    /// A split view's bar colours paint both panes' header bars, the sidebar's as the detail's.
    func testBothPanesHeaderBarsWearTheSplitViewsColours() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    TitledPage(title: "Detail")
                }
                .barBackgroundColor(Color("#FF0000"))
                .barForegroundColor(Color("#FFFFFF"))
            }
            let split = try XCTUnwrap(host.views(GTKSplitView.self).first)
            let sidebar = try XCTUnwrap(split.sidebarFrame)
            let detail = try XCTUnwrap(split.detailFrame)
            host.layOut()

            XCTAssertEqual(GTKTestHost.pixels(of: sidebar.header, at: [(4, 4)]), [0xFFFF_0000], "the sidebar's")
            XCTAssertEqual(GTKTestHost.pixels(of: detail.header, at: [(4, 4)]), [0xFFFF_0000], "the detail's")
        }
    }

    /// A sidebar the user closed takes no focus: Tab from the detail's field goes round the window and never reaches
    /// what the sidebar holds - until the sidebar shows again.
    func testAClosedSidebarTakesNoFocus() throws {
        try onUIThread {
            let open = State(wrappedValue: true)
            let host = GTKRenderer.running {
                SplitView(open.projectedValue) {
                    VStack { Button("Sign out") }
                } detail: {
                    VStack { TextField(State(wrappedValue: "").projectedValue) }
                }
            }
            let split = try XCTUnwrap(host.views(GTKSplitView.self).first)
            let leave = try XCTUnwrap(host.views(GTKButtonView.self).first { $0.text == "Sign out" })
            let field = try XCTUnwrap(host.views(GTKTextFieldView.self).first)
            host.settle { split.isPresented }
            try XCTUnwrap(split.detailFrame?.sidebarToggle ?? nil).click()
            host.settle { !split.isPresented }
            XCTAssertFalse(open.wrappedValue)
            host.layOut()

            let window = try XCTUnwrap(host.window).widget
            let reaches = { () -> Bool in
                _ = gtk_widget_grab_focus(field.widget)
                for _ in 0..<12 {
                    _ = gtk_widget_child_focus(window, GTK_DIR_TAB_FORWARD)
                    if gtk_widget_has_focus(leave.widget) != 0 { return true }
                }
                return false
            }
            XCTAssertFalse(reaches(), "the closed sidebar's button")

            try XCTUnwrap(split.detailFrame?.sidebarToggle ?? nil).click()
            host.settle { split.isPresented }
            XCTAssertTrue(reaches(), "open again, it takes the focus")
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
            host.runtime.pump.turn()
            XCTAssertEqual(navigation.frames.map(\.chrome.title), ["Home", "Page 2"])
            XCTAssertNotNil(navigation.frames.last?.sidebarToggle)
            XCTAssertEqual(host.windowTitle, "Page 2")
        }
    }
}

final class GTKTabViewTests: XCTestCase {
    /// A tabbed view shown by the window stands in a frame whose switcher stands in a bar of its own beneath the
    /// header bar, which carries the chosen tab's title; the user's choice reaches the selection, the pages hear it,
    /// and the header bar carries the chosen tab's actions.
    func testTheSwitcherChoosesATabBeneathTheHeaderBar() throws {
        try onUIThread {
            let tab = State(wrappedValue: "one")
            let log = Received<String>()
            let host = GTKRenderer.running {
                TabView(["one", "two"]) { name in
                    TitledPage(
                        title: name == "one" ? "One" : "Two", log: log,
                        actions: name == "two" ? [ToolbarItem("Share")] : [])
                }
                .selection(tab.projectedValue)
            }
            let tabs = try XCTUnwrap(host.views(GTKTabView.self).first)
            let frame = try XCTUnwrap(host.window?.pageFrame)
            XCTAssertTrue(frame.chrome.tabs === tabs.switcher)
            XCTAssertEqual(frame.chrome.title, "One", "nothing beneath: the chosen tab names the frame")
            XCTAssertEqual(gtk_widget_is_ancestor(tabs.switcher.widget, frame.header), 0, "not in the header bar")
            XCTAssertNotEqual(gtk_widget_is_ancestor(tabs.switcher.widget, frame.widget), 0, "but in the frame's bars")

            log.values = []
            tabs.selectByUser(1)
            host.runtime.pump.turn()
            XCTAssertEqual(tab.wrappedValue, "two")
            XCTAssertEqual(log.values, ["One disappearing", "Two appearing"])
            XCTAssertEqual(frame.buttons.map(\.text), ["Share"])
        }
    }

    /// A tabbed view pushed on a stack is a page of it, in a frame holding its switcher beneath the header bar, which
    /// - and the window - keeps the title of the page beneath.
    func testATabViewPushedOnAStackStandsInAFrame() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                NavigationStack(State(wrappedValue: [1]).projectedValue) {
                    TitledPage(title: "Home")
                } destination: { _ in
                    TabView(["a", "b"]) { name in TitledPage(title: name) }
                }
            }
            let tabs = try XCTUnwrap(host.views(GTKTabView.self).first)
            let navigation = try XCTUnwrap(host.views(GTKNavigationView.self).first)
            XCTAssertTrue(navigation.frames.last?.chrome.tabs === tabs.switcher)
            XCTAssertEqual(navigation.frames.last?.chrome.title, "Home")
            XCTAssertEqual(host.windowTitle, "Home")
        }
    }
}
