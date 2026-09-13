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
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(titleBar()))

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
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertEqual(window.toolbarStyle, .unifiedCompact)

        trailing.clickForTesting()
        XCTAssertEqual(reported.map(\.0), [91])
    }

    @MainActor
    func testTitleBarPresentsItsTitleSubtitleIconAndColors() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(titleBar(), windowTitle: "Workspace"))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let toolbar = try XCTUnwrap(window.toolbar)
        let descendants = toolbar.items.compactMap(\.view).flatMap { [$0] + $0.descendants }
        let labels = descendants.compactMap { $0 as? NSTextField }
        let icon = descendants.compactMap { $0 as? NSImageView }.first
        let foreground = NSColor(
            calibratedRed: 246.0 / 255.0,
            green: 244.0 / 255.0,
            blue: 255.0 / 255.0,
            alpha: 1)

        XCTAssertEqual(window.title, "Workspace")
        XCTAssertEqual(window.subtitle, "Personal")
        XCTAssertNotNil(labels.first { $0.stringValue == "Notes" })
        XCTAssertEqual(labels.first { $0.stringValue == "Notes" }?.textColor, foreground)
        XCTAssertEqual(labels.first { $0.stringValue == "Personal" }?.textColor, foreground)
        XCTAssertNotNil(icon?.image)
        XCTAssertTrue(window.backgroundColor.isEqual(NSColor(
            calibratedRed: 54.0 / 255.0,
            green: 42.0 / 255.0,
            blue: 86.0 / 255.0,
            alpha: 1)))
    }

    @MainActor
    func testRemovingTitleBarRestoresUnadornedNativeWindowChrome() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(titleBar()))
        renderer.applyForTesting(tree(nil))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        XCTAssertNil(window.toolbar)
        XCTAssertFalse(window.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertEqual(window.title, "Page")
        XCTAssertEqual(window.subtitle, "")
        XCTAssertTrue(window.backgroundColor.isEqual(NSColor.windowBackgroundColor))
    }

    @MainActor
    func testTitleBarUpdatesInPlaceAndMovesItsPresentedColors() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in },
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(titleBar(
            title: "Notes",
            subtitle: "Personal",
            background: (0, 0, 0),
            foreground: (0, 0, 0))))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let toolbar = try XCTUnwrap(window.toolbar)
        let trailing = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("title-trailing")) as? AppKitButtonView)

        var changed = titleBar(
            title: "Archive",
            subtitle: "Shared",
            background: (200, 100, 50),
            foreground: (100, 200, 50))
        changed.transitions[.backgroundColor] = HostTransition(motion: .eased(200, .linear))
        changed.transitions[.foregroundColor] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(tree(changed))

        XCTAssertTrue(window.toolbar === toolbar)
        XCTAssertTrue(renderer.viewForTesting(id: .manual("title-trailing")) === trailing)
        XCTAssertEqual(window.title, "Page")
        XCTAssertEqual(window.subtitle, "Shared")
        assertColor(window.backgroundColor, equals: (0, 0, 0))

        now = 100
        renderer.advanceMotionsForTesting()

        XCTAssertTrue(window.toolbar === toolbar)
        assertColor(window.backgroundColor, equals: (100, 50, 25))
        let labels = toolbar.items.compactMap(\.view)
            .flatMap { [$0] + $0.descendants }
            .compactMap { $0 as? NSTextField }
        assertColor(
            try XCTUnwrap(labels.first { $0.stringValue == "Archive" }?.textColor),
            equals: (50, 100, 25))

        now = 200
        renderer.advanceMotionsForTesting()
        assertColor(window.backgroundColor, equals: (200, 100, 50))
        XCTAssertFalse(renderer.propertyMotionsActiveForTesting)
    }

    @MainActor
    func testTitleBarKeepsPageChromeInsideTheNativeContentLayout() throws {
        let renderer = AppKitRenderer(
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
        let renderer = AppKitRenderer(
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
        XCTAssertEqual(navigation.frame, content.bounds)

        renderer.applyForTesting(navigationTree(titleBar()))
        content.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(content.safeAreaInsets.top, 0)
        XCTAssertEqual(navigation.frame, content.safeAreaRect)
    }

    @MainActor
    func testTitleBarContainsNestedFlyoutAndScrollInsideNativeContent() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(flyoutTree(titleBar()))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        let flyout = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitFlyoutView)
        let scroll = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("scroll")) as? AppKitScrollView)
        content.layoutSubtreeIfNeeded()

        XCTAssertEqual(flyout.frame, content.safeAreaRect)
        XCTAssertEqual(flyout.splitControllerForTesting.view.frame, flyout.bounds)
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

        var page = HostPatch(id: .manual("page"), type: .contentPage)
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
        background: (UInt8, UInt8, UInt8) = (54, 42, 86),
        foreground: (UInt8, UInt8, UInt8) = (246, 244, 255)
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
        bar.properties[.foregroundColor] = .color(
            red: foreground.0, green: foreground.1, blue: foreground.2, alpha: 255)
        bar.properties[.backgroundColor] = .color(
            red: background.0, green: background.1, blue: background.2, alpha: 255)
        bar.children = .arranged([leadingSlot, centerSlot, trailingSlot])
        return bar
    }

    func navigationTree(_ bar: HostPatch?) -> HostPatch {
        var label = HostPatch(id: .manual("page-label"), type: .label)
        label.properties[.text] = .string("Page")

        var page = HostPatch(id: .manual("page"), type: .contentPage)
        page.properties[.title] = .string("Page")
        page.children = .arranged([label])

        var navigation = HostPatch(id: .manual("navigation"), type: .navigationPage)
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
        var page = HostPatch(id: .manual("page"), type: .contentPage)
        page.properties[.title] = .string("Page")
        page.children = .arranged([scroll])
        var navigation = HostPatch(id: .manual("navigation"), type: .navigationPage)
        navigation.children = .arranged([page])

        var menuLabel = HostPatch(id: .manual("menu-label"), type: .label)
        menuLabel.properties[.text] = .string("Menu")
        var menu = HostPatch(id: .manual("menu"), type: .contentPage)
        menu.children = .arranged([menuLabel])

        var flyout = HostPatch(id: .manual("flyout"), type: .flyoutPage)
        flyout.properties[.flyoutLayoutBehavior] = .enumeration(1)
        flyout.children = .arranged([menu, navigation])

        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .arranged([flyout, bar])
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }

    func assertColor(
        _ color: NSColor,
        equals expected: (UInt8, UInt8, UInt8),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(color.redComponent * 255, CGFloat(expected.0), accuracy: 0.6,
                       file: file, line: line)
        XCTAssertEqual(color.greenComponent * 255, CGFloat(expected.1), accuracy: 0.6,
                       file: file, line: line)
        XCTAssertEqual(color.blueComponent * 255, CGFloat(expected.2), accuracy: 0.6,
                       file: file, line: line)
    }
}

private extension NSView {
    var descendants: [NSView] {
        subviews + subviews.flatMap(\.descendants)
    }
}

#endif
