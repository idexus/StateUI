// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitTitleBarTests: XCTestCase {
    @MainActor
    func testTitleBarUsesANativeToolbarWithInteractiveStateUISlots() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(titleBar(background: nil)))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let toolbar = try XCTUnwrap(window.toolbar)
        let leading = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("title-leading")) as? AppKitButtonView)
        let center = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("title-center")) as? AppKitLabelView)
        let trailing = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("title-trailing")) as? AppKitButtonView)
        let itemViews = toolbar.items.compactMap(\.view)

        XCTAssertTrue(itemViews.contains { $0 === leading })
        XCTAssertTrue(itemViews.contains { $0 === center })
        XCTAssertTrue(itemViews.contains { $0 === trailing })
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertEqual(window.toolbarStyle, .unified)

        trailing.clickForTesting()
        XCTAssertEqual(reported.map(\.0), [91])
    }

    /// The title bar's own title is text at the trailing edge of the
    /// window's title bar, in the system's colours rather than a toolbar
    /// control's glass, while the visible page names the window. A foreground
    /// with no background written keeps the system's colours: on the
    /// toolbar's material it could vanish.
    @MainActor
    func testTitleBarTitleStandsAtTheTrailingEdgeInSystemColours() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(titleBar(background: nil), windowTitle: "Workspace"))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let window = try XCTUnwrap(controller.window)
        let accessory = try XCTUnwrap(controller.titleAccessoryForTesting)
        let cluster = controller.titleClusterForTesting

        XCTAssertEqual(window.title, "Page")
        XCTAssertEqual(accessory.layoutAttribute, .trailing)
        XCTAssertTrue(accessory.view === cluster)
        XCTAssertTrue(window.titlebarAccessoryViewControllers.contains(accessory))
        XCTAssertFalse(controller.toolbarForTesting.toolbar.items.contains { $0.view === cluster })
        XCTAssertEqual(cluster.titleForTesting, "Notes")
        XCTAssertEqual(cluster.subtitleForTesting, "Personal")
        XCTAssertEqual(cluster.titleColorForTesting, .labelColor)
        XCTAssertNotNil(cluster.imageForTesting)
        XCTAssertTrue(window.backgroundColor.isEqual(NSColor.windowBackgroundColor))
    }

    @MainActor
    func testRemovingTitleBarLeavesThePlainNativeWindowChrome() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(titleBar()))
        renderer.applyForTesting(tree(nil))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let window = try XCTUnwrap(controller.window)
        XCTAssertTrue(window.toolbar === controller.toolbarForTesting.toolbar)
        XCTAssertFalse(controller.toolbarForTesting.toolbar.items.contains { $0.view != nil })
        XCTAssertNil(controller.titleAccessoryForTesting)
        XCTAssertTrue(window.titlebarAccessoryViewControllers.isEmpty)
        XCTAssertEqual(window.title, "Page")
        XCTAssertEqual(window.subtitle, "")
        XCTAssertTrue(window.backgroundColor.isEqual(NSColor.windowBackgroundColor))
        XCTAssertFalse(window.titlebarAppearsTransparent)
        XCTAssertNil((window.contentView as? AppKitWindowContentView)?.barColor)
    }

    /// A title bar that writes its background paints the band the title bar
    /// and toolbar cover and the window's background, and its own title
    /// takes its foreground there.
    @MainActor
    func testAWrittenTitleBarBackgroundPaintsTheBandAndColoursItsTitle() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(titleBar()))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let window = try XCTUnwrap(controller.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(content.barColor, NSColor(
            srgbRed: 54 / 255, green: 42 / 255, blue: 86 / 255, alpha: 1))
        XCTAssertEqual(controller.titleClusterForTesting.titleColorForTesting, NSColor(
            srgbRed: 246 / 255, green: 244 / 255, blue: 1, alpha: 1))
        XCTAssertEqual(window.backgroundColor, NSColor(
            srgbRed: 54 / 255, green: 42 / 255, blue: 86 / 255, alpha: 1))
    }

    @MainActor
    func testTitleBarUpdatesInPlace() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(titleBar(title: "Notes", subtitle: "Personal")))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let window = try XCTUnwrap(controller.window)
        let toolbar = try XCTUnwrap(window.toolbar)
        let trailing = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("title-trailing")) as? AppKitButtonView)

        renderer.applyForTesting(tree(titleBar(title: "Archive", subtitle: "Shared")))

        XCTAssertTrue(window.toolbar === toolbar)
        XCTAssertTrue(renderer.viewForTesting(id: .manual("title-trailing")) === trailing)
        XCTAssertTrue(toolbar.items.contains { $0.view === trailing })
        XCTAssertEqual(window.title, "Page")
        XCTAssertEqual(controller.titleClusterForTesting.titleForTesting, "Archive")
        XCTAssertEqual(controller.titleClusterForTesting.subtitleForTesting, "Shared")
    }

    @MainActor
    func testTitleBarKeepsPageChromeInsideTheNativeContentLayout() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(navigationTree(titleBar()))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        let navigation = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("navigation")) as? AppKitNavigationView)
        content.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(content.safeAreaInsets.top, 0)
        XCTAssertEqual(navigation.frame, content.safeAreaRect)
    }

    @MainActor
    func testAddingTitleBarRelaysOutTheExistingPageInsideNativeContent() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(navigationTree(nil))
        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        let navigation = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("navigation")) as? AppKitNavigationView)
        content.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(content.safeAreaInsets.top, 0)
        XCTAssertEqual(navigation.frame, content.safeAreaRect)

        renderer.applyForTesting(navigationTree(titleBar()))
        content.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(content.safeAreaInsets.top, 0)
        XCTAssertEqual(navigation.frame, content.safeAreaRect)
    }

    @MainActor
    func testTitleBarContainsNestedFlyoutAndScrollInsideNativeContent() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(flyoutTree(titleBar()))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        let flyout = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        let scroll = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("scroll")) as? AppKitScrollView)
        content.layoutSubtreeIfNeeded()

        XCTAssertEqual(flyout.frame, content.bounds)
        XCTAssertEqual(flyout.splitController.view.frame, flyout.bounds)
        let scrollFrame = content.convert(scroll.bounds, from: scroll)
        let hierarchy = sequence(first: scroll as NSView?) { $0?.superview }
            .prefix(8)
            .compactMap { $0 }
            .map { "\(type(of: $0))=\($0.frame)" }
            .joined(separator: ", ")
        XCTAssertGreaterThanOrEqual(
            scrollFrame.minY,
            content.safeAreaRect.minY,
            "scroll=\(scrollFrame); \(hierarchy)")
        XCTAssertLessThanOrEqual(
            scrollFrame.maxY,
            content.safeAreaRect.maxY,
            "scroll=\(scrollFrame); \(hierarchy)")
    }
}

private extension AppKitTitleBarTests {
    func tree(_ bar: HostPatch?, windowTitle: String? = nil) -> HostPatch {
        var label = HostPatch(id: .manual("page-label"), type: .label)
        label.properties[.text] = .string("Page")

        var page = HostPatch(id: .manual("page"), type: .page)
        page.properties[.title] = .string("Page")
        page.children = .arranged([label])

        var children = [page]
        if let bar { children.append(bar) }

        var window = HostPatch(id: .manual("window"), type: .window)
        if let windowTitle { window.properties[.title] = .string(windowTitle) }
        window.children = .arranged(children)

        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])

        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }

    func titleBar(
        title: String = "Notes",
        subtitle: String = "Personal",
        background: (UInt8, UInt8, UInt8)? = (54, 42, 86),
        foreground: (UInt8, UInt8, UInt8)? = (246, 244, 255)
    ) -> HostPatch {
        var leading = HostPatch(id: .manual("title-leading"), type: .button)
        leading.properties[.text] = .string("Leading")
        var leadingSlot = HostPatch(id: .manual("leading-slot"), type: .leadingContent)
        leadingSlot.children = .arranged([leading])

        var center = HostPatch(id: .manual("title-center"), type: .label)
        center.properties[.text] = .string("Center")
        var centerSlot = HostPatch(id: .manual("center-slot"), type: .content)
        centerSlot.children = .arranged([center])

        var trailing = HostPatch(id: .manual("title-trailing"), type: .button)
        trailing.properties[.text] = .string("Trailing")
        trailing.events = .replace([.clicked: 91])
        var trailingSlot = HostPatch(id: .manual("trailing-slot"), type: .trailingContent)
        trailingSlot.children = .arranged([trailing])

        var bar = HostPatch(id: .manual("title-bar"), type: .titleBar)
        bar.properties[.title] = .string(title)
        bar.properties[.subtitle] = .string(subtitle)
        bar.properties[.icon] = .string("notes.png")
        if let foreground {
            bar.properties[.barForegroundColor] = .color(
                red: foreground.0, green: foreground.1, blue: foreground.2, alpha: 255)
        }
        if let background {
            bar.properties[.background] = .color(
                red: background.0, green: background.1, blue: background.2, alpha: 255)
        }
        bar.children = .arranged([leadingSlot, centerSlot, trailingSlot])
        return bar
    }

    func navigationTree(_ bar: HostPatch?) -> HostPatch {
        var label = HostPatch(id: .manual("page-label"), type: .label)
        label.properties[.text] = .string("Page")

        var page = HostPatch(id: .manual("page"), type: .page)
        page.properties[.title] = .string("Page")
        page.children = .arranged([label])

        var navigation = HostPatch(id: .manual("navigation"), type: .navigationStack)
        navigation.children = .arranged([page])

        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .arranged([navigation] + (bar.map { [$0] } ?? []))

        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])

        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }

    func flyoutTree(_ bar: HostPatch) -> HostPatch {
        let rows = (0..<30).map { index -> HostPatch in
            var row = HostPatch(id: .manual("row-\(index)"), type: .label)
            row.properties[.text] = .string("Row \(index)")
            return row
        }
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.properties[.spacing] = .number(12)
        stack.children = .arranged(rows)
        var scroll = HostPatch(id: .manual("scroll"), type: .scrollView)
        scroll.children = .arranged([stack])
        var page = HostPatch(id: .manual("page"), type: .page)
        page.properties[.title] = .string("Page")
        page.children = .arranged([scroll])
        var navigation = HostPatch(id: .manual("navigation"), type: .navigationStack)
        navigation.children = .arranged([page])

        var menuLabel = HostPatch(id: .manual("menu-label"), type: .label)
        menuLabel.properties[.text] = .string("Menu")
        var menu = HostPatch(id: .manual("menu"), type: .page)
        menu.children = .arranged([menuLabel])

        var flyout = HostPatch(id: .manual("flyout"), type: .splitView)
        flyout.children = .arranged([menu, navigation])

        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .arranged([flyout, bar])
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }
}

#endif
