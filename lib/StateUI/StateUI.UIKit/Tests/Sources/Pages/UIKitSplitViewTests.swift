// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A split view's columns as UIKit shows them: the sidebar over the detail in a narrow room, as on a phone, and
/// beside it in a wide one, as on an iPad.
@MainActor
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

    /// A sidebar beside the detail is a column beside its page, no part of what the page runs under: content ignoring
    /// the safe area on every edge stands from the sidebar's edge, and runs under the bars and out to the window's
    /// other edges.
    @MainActor
    func testADetailRunningUnderItsBarsStandsBesideTheSidebar() throws {
        let host = UIKitRenderer.running(reducesMotion: true) {
            SplitView(State(wrappedValue: true).projectedValue) { Text("Sidebar") } detail: {
                ZStack {}.ignoresSafeArea(.all).id("content")
            }
        }
        defer { host.finish() }
        let split = try XCTUnwrap(Self.controller(of: .splitView, in: host) as? UISplitViewController)
        host.settle { split.view.window != nil && split.displayMode != .secondaryOnly }
        guard split.displayMode == .oneBesideSecondary else { throw XCTSkip("a phone's sidebar slides over the detail") }
        let content = { (host.runtime.tree.root?.first(id: .manual("content"))?.native as? UIKitElement)?.view }
        let sidebar = try XCTUnwrap(split.viewController(for: .primary)?.view)
        host.settle { content()?.window != nil }
        let view = try XCTUnwrap(content())
        let frame = view.convert(view.bounds, to: nil)
        let window = try XCTUnwrap(view.window).bounds

        XCTAssertGreaterThanOrEqual(frame.minX, sidebar.convert(sidebar.bounds, to: nil).maxX - 0.5, "beside the sidebar")
        XCTAssertEqual(frame.minY, window.minY, accuracy: 0.5, "under the bar")
        XCTAssertEqual(frame.maxX, window.maxX, accuracy: 0.5, "out to the trailing edge")
    }

    /// A sidebar whose page says no title names its column's bar by the application's name; the detail stays
    /// untitled.
    @MainActor
    func testAnUntitledSidebarIsNamedByTheApplication() throws {
        // The tests' host reports no application; one does as it starts.
        HostBoundary.setApplicationInfo(HostApplicationInfo(name: "Notes", packageName: "", versionString: "", buildString: ""))
        let host = UIKitRenderer.running(reducesMotion: true) {
            SplitView(State(wrappedValue: true).projectedValue) { Text("Sidebar") } detail: { Text("Detail") }
        }
        defer { host.finish() }
        let split = try XCTUnwrap(host.runtime.tree.root?.first(type: .splitView))
        let name = host.runtime.core.applicationName

        XCTAssertFalse(name.isEmpty, "the host reported the application's name")
        let chrome = { (page: MountedElement?) in (page?.native as? UIKitElement)?.chrome.title }
        XCTAssertEqual(chrome(split.children.first), name)
        XCTAssertEqual(chrome(split.children.dropFirst().first), "")
    }

    /// A sidebar the application paints stands apart from the detail by a line of UIKit's separator color down its
    /// edge, and on UIKit's sidebar material all the same - under which the detail's column slides with the sidebar
    /// as it shows and hides; UIKit's plain column parts them by its own line, and its detail jumps to its width.
    @MainActor
    func testASidebarTheApplicationPaintsStandsApartFromTheDetail() throws {
        let painted = State(wrappedValue: true)
        let host = UIKitRenderer.running(reducesMotion: true) {
            if painted.wrappedValue {
                SplitView(State(wrappedValue: true).projectedValue) { Text("Sidebar") } detail: { Text("Detail") }
                    .sidebarBackground(.color(Color(hex: 0x251E4C)))
            } else {
                SplitView(State(wrappedValue: true).projectedValue) { Text("Sidebar") } detail: { Text("Detail") }
            }
        }
        defer { host.finish() }
        let split = { Self.controller(of: .splitView, in: host) as? UIKitSplitViewController }
        host.settle { split()?.view.window != nil }
        XCTAssertEqual(split()?.primaryBackgroundStyle, .sidebar, "UIKit's sidebar material, its columns sliding together")
        let sidebar = try XCTUnwrap(split()?.viewController(for: .primary)?.view)
        XCTAssertTrue(split()?.separator.superview === sidebar, "a line down the sidebar's edge")
        XCTAssertEqual(split()?.separator.backgroundColor, .opaqueSeparator)

        painted.wrappedValue = false
        host.settle { split()?.separator.superview == nil }
        XCTAssertNil(split()?.separator.superview, "the platform's own sidebar draws no line of the host's")
        XCTAssertEqual(split()?.primaryBackgroundStyle, .sidebar, "the platform's own sidebar")
    }

    /// A blur or glass under the sidebar is UIKit's own effect under what the sidebar page shows - beside the
    /// detail and over it alike - never a color standing in for it.
    @MainActor
    func testASidebarOnGlassStandsOnUIKitsEffect() throws {
        let host = UIKitRenderer.running(reducesMotion: true) {
            SplitView(State(wrappedValue: true).projectedValue) { Text("Sidebar") } detail: { Text("Detail") }
                .sidebarBackground(.glass(.regular))
                .flyoutBackground(.glass(.regular))
        }
        defer { host.finish() }
        let split = { Self.controller(of: .splitView, in: host) as? UISplitViewController }
        func grounds(in view: UIView?) -> [UIKitBackdropView] {
            guard let view else { return [] }
            return (view as? UIKitBackdropView).map { [$0] } ?? view.subviews.flatMap { grounds(in: $0) }
        }
        host.settle { grounds(in: split()?.view).contains { $0.effect is UIGlassEffect } }

        XCTAssertTrue(grounds(in: split()?.view).contains { $0.effect is UIGlassEffect }, "UIKit's glass under it")
    }

    /// A page pushed as the sidebar goes - a group chosen from a menu - stands at once: it is laid out where it
    /// stands, never grown from nothing with the sidebar's slide.
    @MainActor
    func testAPagePushedAsTheSidebarGoesIsNotGrownFromNothing() throws {
        try assertStandsAtOnce(from: [], to: [1])
    }

    /// A page taking the top's place as the sidebar goes - another group chosen from the menu - stands at once too.
    @MainActor
    func testAPageReplacingTheTopAsTheSidebarGoesIsNotGrownFromNothing() throws {
        try assertStandsAtOnce(from: [1], to: [2])
    }

    /// The stack's top page, its path moved from `before` to `after` as the sidebar goes, stands where it is laid
    /// out from its first frame - a page taking the top's place laid out as the slide begins - and fills its column
    /// once the slide ends.
    private func assertStandsAtOnce(
        from before: [Int], to after: [Int], file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let path = State(wrappedValue: before)
        let menuOpen = State(wrappedValue: true)
        let host = UIKitRenderer.running {
            SplitView(menuOpen.projectedValue) { Text("Sidebar") } detail: {
                NavigationStack(path.projectedValue) { Text("Home") } destination: { number in Text("Group \(number)") }
            }
        }
        defer { host.finish() }
        let split = try XCTUnwrap(Self.controller(of: .splitView, in: host) as? UISplitViewController)
        let stack = try XCTUnwrap(Self.controller(of: .navigationStack, in: host) as? UINavigationController)
        host.settle {
            split.view.window != nil && split.displayMode != .secondaryOnly && stack.transitionCoordinator == nil
        }

        path.wrappedValue = after
        menuOpen.wrappedValue = false
        host.runtime.pump.turn()

        let top = "Group \(after.last ?? 0)"
        let words = try XCTUnwrap(host.views(UIKitTextView.self).first { $0.attributedText?.string == top })
        if before.count == after.count {
            // Shown without a move, the page stands laid out as the slide begins, which carries it from its place.
            XCTAssertNotNil(words.window, "the page stands in the window as the slide begins", file: file, line: line)
            XCTAssertGreaterThan(words.bounds.width, 0, "the page is laid out as the slide begins",
                                 file: file, line: line)
        }
        var grown: [String] = []
        var each: UIView? = words
        while let view = each {
            // Grown from nothing: its size travels from a size as much smaller as it is - from zero.
            if let size = view.layer.animation(forKey: "bounds.size") as? CABasicAnimation, size.isAdditive,
               let from = (size.fromValue as? NSValue)?.cgSizeValue, view.bounds.width > 0,
               from.width == -view.bounds.width, from.height == -view.bounds.height {
                grown.append("\(type(of: view))")
            }
            each = view.superview
        }
        XCTAssertEqual(grown, [], "the page stands where it is laid out, from its first frame", file: file, line: line)

        host.settle { split.transitionCoordinator == nil && stack.transitionCoordinator == nil }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
        let page = try XCTUnwrap(stack.topViewController?.view)
        XCTAssertEqual(page.convert(page.bounds, to: stack.view), stack.view.bounds, "the page fills its column",
                       file: file, line: line)
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
