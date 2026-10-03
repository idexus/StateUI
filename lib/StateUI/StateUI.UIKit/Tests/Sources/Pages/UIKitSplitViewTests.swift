// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A split view's columns as UIKit shows them: the sidebar over the detail in a narrow room, as on a phone, and
/// beside it in a wide one, as on an iPad.
final class UIKitSplitViewTests: XCTestCase {
    /// In a narrow room the split view stays two columns - the sidebar sliding over the detail, never one column
    /// standing in for the other - and each column is as narrow as the room: its tabs and sheets are a phone's.
    @MainActor
    func testTheSidebarSlidesOverTheDetailInANarrowRoom() throws {
        let menuOpen = State(wrappedValue: false)
        let host = UIKitRenderer.running(reducesMotion: true) {
            SplitView(menuOpen.projectedValue) { Text("Sidebar") } detail: { Text("Detail") }
        }
        defer { host.finish() }
        let split = try XCTUnwrap(Self.controller(of: .splitView, in: host) as? UISplitViewController)
        host.settle { split.view.window != nil }
        let room = try XCTUnwrap(split.view.window?.windowScene?.traitCollection.horizontalSizeClass)

        XCTAssertFalse(split.isCollapsed, "two columns, never one")
        if room == .compact {
            XCTAssertEqual(split.preferredSplitBehavior, .overlay, "the sidebar over the detail")
            for column in split.children {
                XCTAssertEqual(column.traitCollection.horizontalSizeClass, .compact, "a column as narrow as the room")
            }
        }

        menuOpen.wrappedValue = true
        host.runtime.pump.turn()
        host.settle { split.displayMode != .secondaryOnly }
        XCTAssertEqual(split.displayMode, room == .compact ? .oneOverSecondary : .oneBesideSecondary)
        XCTAssertTrue(menuOpen.wrappedValue, "the program's move is not told back as another")
    }

    /// A detail the tree replaces - a stack with pages pushed on it by tabs, the stack emptied in the same move, once
    /// the sidebar showed and hid - stands in the window in place of the one before.
    @MainActor
    func testADetailReplacedStandsInItsPlace() throws {
        let tabbed = State(wrappedValue: false)
        let path = State(wrappedValue: [1, 2])
        let menuOpen = State(wrappedValue: true)
        let host = UIKitRenderer.running(reducesMotion: true) {
            SplitView(menuOpen.projectedValue) { Text("Sidebar") } detail: {
                if tabbed.wrappedValue {
                    TabView([0, 1]) { tab in Text("Tab \(tab)") }
                } else {
                    NavigationStack(path.projectedValue) { Text("Stacked") }
                        destination: { number in Text("Pushed \(number)") }
                }
            }
        }
        defer { host.finish() }
        let stack = try XCTUnwrap(Self.controller(of: .navigationStack, in: host))
        host.settle { false }
        menuOpen.wrappedValue = false
        host.runtime.pump.turn()
        host.settle { stack.view.window != nil }
        XCTAssertNotNil(stack.view.window, "the stack stands first")

        tabbed.wrappedValue = true
        path.wrappedValue = []
        host.runtime.pump.turn()
        let tabs = try XCTUnwrap(Self.controller(of: .tabView, in: host))
        host.settle { tabs.view.window != nil }

        XCTAssertNotNil(tabs.view.window, "the tabs stand in the window")
        XCTAssertNil(stack.view.window, "the stack left it")
        XCTAssertFalse(menuOpen.wrappedValue, "the host's own move is not the user's: the sidebar stays hidden")
    }

    /// Tabs whose chosen tab is a stack stand under that stack's bar alone: the bar of the stack UIKit stands them on
    /// hides over them, and shows again over the sidebar.
    @MainActor
    func testTabsOfStacksStandUnderOneBar() throws {
        let menuOpen = State(wrappedValue: true)
        let host = UIKitRenderer.running(reducesMotion: true) {
            SplitView(menuOpen.projectedValue) { Text("Sidebar") } detail: {
                TabView([0, 1]) { tab in
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) { Text("Tab \(tab)") }
                        destination: { number in Text("Pushed \(number)") }
                }
            }
        }
        defer { host.finish() }
        host.settle { false }
        menuOpen.wrappedValue = false
        host.runtime.pump.turn()
        let tabs = try XCTUnwrap(Self.controller(of: .tabView, in: host))
        host.settle { tabs.view.window != nil && tabs.navigationController?.isNavigationBarHidden != false }

        XCTAssertNotNil(tabs.view.window)
        XCTAssertNotEqual(tabs.navigationController?.isNavigationBarHidden, false, "no bar laid over the tabs")

        let sidebar = try XCTUnwrap((Self.controller(of: .splitView, in: host) as? UISplitViewController)?
            .viewController(for: .primary))
        menuOpen.wrappedValue = true
        host.runtime.pump.turn()
        host.settle { sidebar.view.window != nil && sidebar.navigationController?.isNavigationBarHidden == false }
        XCTAssertEqual(sidebar.navigationController?.isNavigationBarHidden, false, "the sidebar's bar shows")
    }

    /// The controller of the first element of `type` in the host's tree.
    @MainActor
    private static func controller(of type: NodeType, in host: UIKitRenderer) -> UIViewController? {
        func find(_ element: MountedElement) -> MountedElement? {
            element.type == type ? element : element.children.lazy.compactMap(find).first
        }
        return host.runtime.tree.root.flatMap(find).flatMap { ($0.native as? UIKitElement)?.controller }
    }
}
