// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// The bar an arrangement declares, in AppKit's window chrome: the application's title area and the bar's colours.
final class AppKitBarTests: XCTestCase {
    /// The title area is text at the trailing edge of the window's title bar, in the system's colours rather than a
    /// toolbar control's glass, while the visible page names the window. A foreground with no background declared
    /// keeps the system's colours: on the toolbar's material it could vanish.
    @MainActor
    func testTheTitleAreaStandsAtTheTrailingEdgeInSystemColours() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(bar(background: nil), windowTitle: "Workspace"))

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
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertEqual(window.toolbarStyle, .unified)
        XCTAssertTrue(window.backgroundColor.isEqual(NSColor.windowBackgroundColor))
    }

    /// With nothing declared any more - each value arriving as nothing - the window keeps the plain native chrome:
    /// no accessory, the system's background.
    @MainActor
    func testTakingTheBarAwayLeavesThePlainNativeWindowChrome() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(bar()))
        renderer.applyForTesting(tree(bar().mapValues { _ in .nothing }))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let window = try XCTUnwrap(controller.window)
        XCTAssertTrue(window.toolbar === controller.toolbarForTesting.toolbar)
        XCTAssertNil(controller.titleAccessoryForTesting)
        XCTAssertTrue(window.titlebarAccessoryViewControllers.isEmpty)
        XCTAssertEqual(window.title, "Page")
        XCTAssertEqual(window.subtitle, "")
        XCTAssertTrue(window.backgroundColor.isEqual(NSColor.windowBackgroundColor))
        XCTAssertFalse(window.titlebarAppearsTransparent)
        XCTAssertNil((window.contentView as? AppKitWindowContentView)?.barColor)
    }

    /// A declared bar colour paints the band the title bar and toolbar cover and the window's background, and the
    /// title area takes the declared foreground there.
    @MainActor
    func testADeclaredBarColourPaintsTheBandAndColoursTheTitleArea() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(bar()))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let window = try XCTUnwrap(controller.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(content.barColor, NSColor(srgbRed: 54 / 255, green: 42 / 255, blue: 86 / 255, alpha: 1))
        XCTAssertEqual(controller.titleClusterForTesting.titleColorForTesting, NSColor(
            srgbRed: 246 / 255, green: 244 / 255, blue: 1, alpha: 1))
        XCTAssertEqual(window.backgroundColor, NSColor(srgbRed: 54 / 255, green: 42 / 255, blue: 86 / 255, alpha: 1))
    }

    /// The title area follows what the arrangement declares, in the same toolbar and accessory.
    @MainActor
    func testTheTitleAreaUpdatesInPlace() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(bar(title: "Notes", subtitle: "Personal")))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let window = try XCTUnwrap(controller.window)
        let toolbar = try XCTUnwrap(window.toolbar)
        let accessory = try XCTUnwrap(controller.titleAccessoryForTesting)

        renderer.applyForTesting(tree(bar(title: "Archive", subtitle: "Shared")))

        XCTAssertTrue(window.toolbar === toolbar)
        XCTAssertTrue(controller.titleAccessoryForTesting === accessory)
        XCTAssertEqual(window.title, "Page")
        XCTAssertEqual(controller.titleClusterForTesting.titleForTesting, "Archive")
        XCTAssertEqual(controller.titleClusterForTesting.subtitleForTesting, "Shared")
    }

    /// A stack declaring the bar keeps the page's content inside the native content layout, and a bar declared later
    /// lays the page out again inside it.
    @MainActor
    func testADeclaredBarKeepsThePageInsideTheNativeContentLayout() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree([:]))
        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        let navigation = try XCTUnwrap(renderer.viewForTesting(id: .manual("navigation")) as? AppKitNavigationView)
        content.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(content.safeAreaInsets.top, 0)
        XCTAssertEqual(navigation.frame, content.safeAreaRect)

        renderer.applyForTesting(tree(bar()))
        content.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(content.safeAreaInsets.top, 0)
        XCTAssertEqual(navigation.frame, content.safeAreaRect)
    }

    /// A split view declaring the bar keeps its sidebar, its stack and a scroll view in the stack inside the native
    /// content.
    @MainActor
    func testASplitViewDeclaringTheBarKeepsItsScrollInsideNativeContent() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(flyoutTree(bar()))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        let flyout = try XCTUnwrap(renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        let scroll = try XCTUnwrap(renderer.viewForTesting(id: .manual("scroll")) as? AppKitScrollView)
        content.layoutSubtreeIfNeeded()

        XCTAssertEqual(flyout.frame, content.bounds)
        XCTAssertEqual(flyout.splitController.view.frame, flyout.bounds)
        XCTAssertEqual(renderer.windowsForTesting.first?.titleClusterForTesting.titleForTesting, "Notes")
        let scrollFrame = content.convert(scroll.bounds, from: scroll)
        let hierarchy = sequence(first: scroll as NSView?) { $0?.superview }
            .prefix(8)
            .compactMap { $0 }
            .map { "\(type(of: $0))=\($0.frame)" }
            .joined(separator: ", ")
        XCTAssertGreaterThanOrEqual(scrollFrame.minY, content.safeAreaRect.minY, "scroll=\(scrollFrame); \(hierarchy)")
        XCTAssertLessThanOrEqual(scrollFrame.maxY, content.safeAreaRect.maxY, "scroll=\(scrollFrame); \(hierarchy)")
    }
}

private extension AppKitBarTests {
    /// A window whose page is a stack declaring `bar` over a page titled "Page".
    func tree(_ bar: [Prop: HostValue], windowTitle: String? = nil) -> HostPatch {
        var label = HostPatch(id: .manual("page-label"), type: .label)
        label.properties[.text] = .string("Page")

        var page = HostPatch(id: .manual("page"), type: .page)
        page.properties[.title] = .string("Page")
        page.children = .arranged([label])

        var navigation = HostPatch(id: .manual("navigation"), type: .navigationStack)
        navigation.properties = bar
        navigation.children = .arranged([page])

        var window = HostPatch(id: .manual("window"), type: .window)
        if let windowTitle { window.properties[.title] = .string(windowTitle) }
        window.children = .arranged([navigation])
        return application(window)
    }

    /// What an arrangement declares of the bar: the application's name, line and mark, and the colours given.
    func bar(
        title: String = "Notes",
        subtitle: String = "Personal",
        background: (UInt8, UInt8, UInt8)? = (54, 42, 86),
        foreground: (UInt8, UInt8, UInt8)? = (246, 244, 255)
    ) -> [Prop: HostValue] {
        var bar: [Prop: HostValue] = [
            .barTitle: .string(title), .barSubtitle: .string(subtitle), .barIcon: .string("notes.png"),
        ]
        if let foreground {
            bar[.barForegroundColor] = .color(red: foreground.0, green: foreground.1, blue: foreground.2, alpha: 255)
        }
        if let background {
            bar[.barBackgroundColor] = .color(red: background.0, green: background.1, blue: background.2, alpha: 255)
        }
        return bar
    }

    /// A window whose page is a split view declaring `bar`: a menu beside a stack over a long scrolling page.
    func flyoutTree(_ bar: [Prop: HostValue]) -> HostPatch {
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
        flyout.properties = bar
        flyout.children = .arranged([menu, navigation])

        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .arranged([flyout])
        return application(window)
    }

    /// `window`, alone in a scene of an application.
    func application(_ window: HostPatch) -> HostPatch {
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }
}

#endif
