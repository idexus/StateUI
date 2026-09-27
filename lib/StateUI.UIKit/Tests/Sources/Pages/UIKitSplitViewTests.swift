// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A split view's columns as UIKit shows them, collapsed into one on a phone and side by side on an iPad.
final class UIKitSplitViewTests: XCTestCase {
    /// A detail the tree replaces - a stack with pages pushed on it by tabs, the stack emptied in the same move, once
    /// the sidebar showed and hid - stands in the window in place of the one before.
    @MainActor
    func testADetailReplacedStandsInItsPlace() throws {
        let tabbed = State(wrappedValue: false)
        let path = State(wrappedValue: [1, 2])
        let menuOpen = State(wrappedValue: true)
        let host = UIKitRenderer.running(reducesMotion: true) {
            SplitView(menuOpen.projectedValue) { Label("Sidebar") } detail: { () -> any Page in
                guard tabbed.wrappedValue else {
                    return NavigationStack(path.projectedValue) { Label("Stacked") }
                        destination: { number in Label("Pushed \(number)") }
                }
                return TabbedView([0, 1]) { tab in Label("Tab \(tab)") }
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
        let tabs = try XCTUnwrap(Self.controller(of: .tabbedView, in: host))
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
            SplitView(menuOpen.projectedValue) { Label("Sidebar") } detail: {
                TabbedView([0, 1]) { tab -> any Page in
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) { Label("Tab \(tab)") }
                        destination: { number in Label("Pushed \(number)") }
                }
            }
        }
        defer { host.finish() }
        host.settle { false }
        menuOpen.wrappedValue = false
        host.runtime.pump.turn()
        let tabs = try XCTUnwrap(Self.controller(of: .tabbedView, in: host))
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
