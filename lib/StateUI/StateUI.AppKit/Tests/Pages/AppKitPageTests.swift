// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

final class AppKitPageTests: XCTestCase {
    /// The top page names the window, and the way back is the system's
    /// navigational toolbar item, labelled by the page it returns to.
    @MainActor
    func testTheWindowToolbarCarriesTheTopPageAndTheWayBack() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var home = page("home", title: "Home")
        home.properties[.backButtonTitle] = .string("Start")
        renderer.applyForTesting(tree(navigation([
            home,
            page("details", title: "Details"),
        ])))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let back = try XCTUnwrap(
            controller.toolbarForTesting.itemForTesting(AppKitWindowToolbar.back))
        XCTAssertEqual(controller.window?.title, "Details")
        XCTAssertEqual(back.label, "Start")
        XCTAssertTrue(back.isNavigational)
        XCTAssertTrue(back.image === AppKitWindowToolbar.backImage)

        renderer.applyForTesting(tree(navigation([home])))

        XCTAssertEqual(controller.window?.title, "Home")
        XCTAssertNil(controller.toolbarForTesting.itemForTesting(AppKitWindowToolbar.back))
    }

    /// The window's chrome is the system's: a unified toolbar over full-size
    /// content, the page in the safe area under it, and the native window
    /// background. With no bar colour written, AppKit keeps its toolbar's own
    /// material.
    @MainActor
    func testANavigationStackStandsUnderTheWindowsNativeToolbar() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(navigation([page("home", title: "Home")])))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let window = try XCTUnwrap(controller.window)
        let content = try XCTUnwrap(window.contentView)
        let navigation = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("navigation")) as? AppKitNavigationView)
        content.layoutSubtreeIfNeeded()
        XCTAssertTrue(window.toolbar === controller.toolbarForTesting.toolbar)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertEqual(window.toolbarStyle, .unified)
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertFalse(window.titlebarAppearsTransparent)
        XCTAssertGreaterThan(content.safeAreaInsets.top, 0)
        XCTAssertEqual(navigation.frame, content.safeAreaRect)
        XCTAssertTrue(navigation.topViewForTesting === renderer.viewForTesting(id: .manual("home")))
        XCTAssertTrue(window.backgroundColor.isEqual(NSColor.windowBackgroundColor))
        XCTAssertNil((content as? AppKitWindowContentView)?.barColor)
    }

    /// A written bar colour paints the band the title bar and toolbar cover
    /// above the page, and the title bar lets it show. The window wears it as
    /// its background too, and a colour taken away gives the material and the
    /// window's own background back.
    @MainActor
    func testAWrittenBarColourPaintsTheBandAboveThePage() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var stack = navigation([page("home", title: "Home")])
        stack.properties[.barBackgroundColor] = .color(
            red: 54, green: 42, blue: 86, alpha: 255)
        renderer.applyForTesting(tree(stack))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let window = try XCTUnwrap(controller.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        content.layoutSubtreeIfNeeded()
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(content.barColor, NSColor(
            srgbRed: 54 / 255, green: 42 / 255, blue: 86 / 255, alpha: 1))
        XCTAssertGreaterThan(content.barBand.height, 0)
        XCTAssertEqual(content.barBand, NSRect(
            x: 0, y: 0, width: content.bounds.width, height: content.safeAreaRect.minY))
        XCTAssertEqual(window.backgroundColor, .windowBackgroundColor, "the bars' colour paints the bars alone")

        // On the band the page's title is the bar's: white on a dark band
        // when no foreground is written. The window keeps its name.
        let toolbar = controller.toolbarForTesting
        let title = try XCTUnwrap(
            toolbar.itemForTesting(AppKitWindowToolbar.title)?.view as? NSTextField)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertEqual(window.title, "Home")
        XCTAssertEqual(title.stringValue, "Home")
        XCTAssertEqual(title.textColor, .white)

        stack.properties[.barBackgroundColor] = .nothing
        renderer.applyForTesting(tree(stack))
        XCTAssertFalse(window.titlebarAppearsTransparent)
        XCTAssertNil(content.barColor)
        XCTAssertTrue(window.backgroundColor.isEqual(NSColor.windowBackgroundColor))
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertNil(toolbar.itemForTesting(AppKitWindowToolbar.title))
    }

    /// On the band a navigation stack paints, the page's title stands in the
    /// foreground the stack writes for its bars.
    @MainActor
    func testAWrittenBarForegroundColoursThePagesTitleOnTheBand() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var stack = navigation([page("home", title: "Home")])
        stack.properties[.barBackgroundColor] = .color(red: 54, green: 42, blue: 86, alpha: 255)
        stack.properties[.barForegroundColor] = .color(red: 51, green: 179, blue: 230, alpha: 255)
        renderer.applyForTesting(tree(stack))

        let toolbar = try XCTUnwrap(renderer.windowsForTesting.first).toolbarForTesting
        let title = try XCTUnwrap(
            toolbar.itemForTesting(AppKitWindowToolbar.title)?.view as? NSTextField)
        XCTAssertEqual(title.stringValue, "Home")
        XCTAssertEqual(title.textColor, NSColor(
            srgbRed: 51 / 255, green: 179 / 255, blue: 230 / 255, alpha: 1))
    }

    /// In a split view the bars' colour paints the window's band, under the
    /// sidebar's glass, and the detail's, which the pane under the bars
    /// paints; the sidebar keeps its own glass.
    @MainActor
    func testAWrittenBarColourPaintsTheBandsUnderTheSplitView() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var stack = navigation([page("home", title: "Home")])
        stack.properties[.barBackgroundColor] = .color(
            red: 54, green: 42, blue: 86, alpha: 255)
        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: page("menu", title: "Menu"),
            detail: stack)))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let window = try XCTUnwrap(controller.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        let split = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(split.detailBarColorForTesting, NSColor(
            srgbRed: 54 / 255, green: 42 / 255, blue: 86 / 255, alpha: 1))
        XCTAssertNil(split.sidebarBarColorForTesting)
        XCTAssertEqual(content.barColor, NSColor(
            srgbRed: 54 / 255, green: 42 / 255, blue: 86 / 255, alpha: 1), "the window's band, under the sidebar")
    }

    /// A written bar colour paints the bars alone: the window around a
    /// floating sidebar keeps the system's background, with the colour written
    /// and once it goes.
    @MainActor
    func testAWrittenBarColourLeavesTheWindowsBackground() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var stack = navigation([page("home", title: "Home")])
        stack.properties[.barBackgroundColor] = .color(
            red: 54, green: 42, blue: 86, alpha: 255)
        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: page("menu", title: "Menu"),
            detail: stack)))

        let painted = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        XCTAssertEqual(painted.backgroundColor, .windowBackgroundColor)

        stack.properties[.barBackgroundColor] = .nothing
        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: page("menu", title: "Menu"),
            detail: stack)))

        let plain = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        XCTAssertEqual(plain.backgroundColor, .windowBackgroundColor,
                       "with no colour written the window is the system's")
    }

    /// A window asked to be translucent lets the desktop show through it: it
    /// is not opaque, keeps no background of its own and lays a material that
    /// blends with what is behind the window under its page - and all of it
    /// goes when nothing asks for it any more.
    @MainActor
    func testATranslucentWindowLaysItsMaterialUnderThePage() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(windowTree(page("home", title: "Home"), translucent: true))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, .clear)
        let material = try XCTUnwrap(content.materialForTesting, "no material under the page")
        XCTAssertEqual(material.blendingMode, .behindWindow)
        XCTAssertTrue(content.subviews.first === material, "the material lies under the page")

        renderer.applyForTesting(windowTree(page("home", title: "Home"), translucent: nil))

        XCTAssertTrue(window.isOpaque)
        XCTAssertTrue(window.backgroundColor.isEqual(NSColor.windowBackgroundColor))
        XCTAssertNil(content.materialForTesting)
    }

    /// On a translucent window a colour written for the bars paints the bars
    /// alone: the window's band, under the floating sidebar's glass, and the
    /// detail's - over the material, which stays the system's; the window keeps
    /// no background, so the desktop shows around the sidebar. An opaque window
    /// keeps the system's background.
    @MainActor
    func testATranslucentWindowsBarColourPaintsTheBarsAlone() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var stack = navigation([page("home", title: "Home")])
        stack.properties[.barBackgroundColor] = .color(
            red: 54, green: 42, blue: 86, alpha: 255)
        renderer.applyForTesting(windowTree(flyout(
            presented: true,
            menu: page("menu", title: "Menu"),
            detail: stack), translucent: true))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        let split = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        let colour = NSColor(srgbRed: 54 / 255, green: 42 / 255, blue: 86 / 255, alpha: 1)
        XCTAssertEqual(window.backgroundColor, .clear, "the material shows around the sidebar")
        XCTAssertEqual(split.detailBarColorForTesting, colour, "the detail's bar wears the colour")
        XCTAssertEqual(content.barColor, colour, "the window's band stands under the sidebar's glass")
        XCTAssertNil(split.sidebarBarColorForTesting, "the sidebar's glass shows the band beneath it")
        XCTAssertNotNil(content.materialForTesting)
        content.layoutSubtreeIfNeeded()
        let order = content.subviews.map { String(describing: type(of: $0)) }
        XCTAssertEqual(order.prefix(3), ["NSVisualEffectView", "NSView", "AppKitSplitView"],
                       "the material, the band over it, the split view over both")

        renderer.applyForTesting(windowTree(flyout(
            presented: true,
            menu: page("menu", title: "Menu"),
            detail: stack), translucent: false))
        XCTAssertEqual(window.backgroundColor, .windowBackgroundColor)
        XCTAssertEqual(split.detailBarColorForTesting, colour)
        XCTAssertNil(split.sidebarBarColorForTesting, "the sidebar's glass shows the band behind it")
        XCTAssertEqual(content.barColor, colour)
        XCTAssertNil(content.materialForTesting)
    }

    /// On a translucent window the material lies under the whole window,
    /// untinted, and a window with no split view paints its bars' band over
    /// it.
    @MainActor
    func testATranslucentWindowsMaterialStaysTheSystems() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var stack = navigation([page("home", title: "Home")])
        stack.properties[.barBackgroundColor] = .color(
            red: 81, green: 43, blue: 212, alpha: 255)
        renderer.applyForTesting(windowTree(stack, translucent: true))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        content.layoutSubtreeIfNeeded()
        let material = try XCTUnwrap(content.materialForTesting)
        XCTAssertEqual(material.frame, content.bounds)
        XCTAssertTrue(material.subviews.allSatisfy(\.isHidden), "nothing lies over the material")
        XCTAssertEqual(content.barColor, NSColor(srgbRed: 81 / 255, green: 43 / 255, blue: 212 / 255, alpha: 1),
                       "the bars' band is painted over the material")
    }

    /// A background written for a translucent window tints its whole material
    /// - under the pages and around the floating sidebar - and lets it show;
    /// another window wears it as its own background, and one that lets the
    /// desktop through is no longer opaque.
    @MainActor
    func testAWindowsBackgroundTintsItsMaterial() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var stack = navigation([page("home", title: "Home")])
        stack.properties[.barBackgroundColor] = .color(red: 81, green: 43, blue: 212, alpha: 255)
        let tint = HostValue.color(red: 81, green: 43, blue: 212, alpha: 38)
        renderer.applyForTesting(windowTree(flyout(
            presented: true,
            menu: page("menu", title: "Menu"),
            detail: stack), translucent: true, background: tint))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        content.layoutSubtreeIfNeeded()
        let material = try XCTUnwrap(content.materialForTesting)
        let over = try XCTUnwrap(content.materialTintForTesting, "no tint over the material")
        XCTAssertFalse(over.isHidden)
        XCTAssertEqual(over.frame, material.bounds, "the tint covers the whole material")
        XCTAssertEqual(over.layer?.backgroundColor?.alpha ?? 0, 38.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(window.backgroundColor, .clear)

        renderer.applyForTesting(windowTree(flyout(
            presented: true,
            menu: page("menu", title: "Menu"),
            detail: stack), translucent: false, background: tint))
        XCTAssertEqual(window.backgroundColor, NSColor(srgbRed: 81 / 255, green: 43 / 255, blue: 212 / 255,
                                                       alpha: 38 / 255), "the window's own background")
        XCTAssertFalse(window.isOpaque, "the desktop shows through the colour's alpha")
        XCTAssertNil(content.materialForTesting)
    }

    /// The detail meets a floating sidebar: its page and its band begin at the
    /// sidebar's trailing edge, the window's margin standing only between the
    /// sidebar and the window's own edges.
    @MainActor
    func testTheDetailMeetsAFloatingSidebar() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var stack = navigation([page("home", title: "Home")])
        stack.properties[.barBackgroundColor] = .color(
            red: 54, green: 42, blue: 86, alpha: 255)
        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: page("menu", title: "Menu"),
            detail: stack), width: 1200))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        window.setContentSize(NSSize(width: 1200, height: 800))
        window.contentView?.layoutSubtreeIfNeeded()

        let split = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        let panes = split.splitController.splitViewItems.map(\.viewController.view)
        let sidebar = panes[0].convert(panes[0].bounds, to: nil)
        let detail = try XCTUnwrap(panes[1] as? AppKitPaneView)
        let shown = try XCTUnwrap(renderer.viewForTesting(id: .manual("navigation")))
        XCTAssertEqual(shown.convert(shown.bounds, to: nil).minX, sidebar.maxX,
                       "the page begins at the sidebar's edge")
        XCTAssertEqual(detail.barBand.minX, 0, "and so does the band")
        // Whether the sidebar floats is AppKit's, and the hosted runner's draws it at the window's edge.
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["CI"] != nil && sidebar.minX == 0,
            """
            this runner's AppKit draws the sidebar at the window's edge (\
            \(ProcessInfo.processInfo.operatingSystemVersionString), Reduce Transparency \
            \(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)); the page and its band met it there
            """)
        XCTAssertGreaterThan(sidebar.minX, 0, "the sidebar floats in the window's margin")
    }

    @MainActor
    func testUserTabSelectionReportsTheSelectedIndexOnce() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(tabbed([
            page("home", title: "Home", events: 100),
            page("browse", title: "Browse", events: 200),
        ], selected: 0, changed: 9)))

        let tabs = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("tabs")) as? AppKitTabView)
        tabs.selectForTesting(1)

        XCTAssertEqual(tabs.selectedIndexForTesting, 1)
    }

    /// A tabbed view on the window's page path shows its tabs in a row
    /// beneath the window's toolbar - beneath the title bar where there is no
    /// split view - one select-one segmented control sharing the width
    /// equally, and none on its content, where nothing is painted. Choosing in
    /// the row is the user choosing.
    @MainActor
    func testAWindowsTabViewSelectsFromTheRowBeneathItsToolbar() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }
        let pages = [
            page("home", title: "Home", events: 100),
            page("browse", title: "Browse", events: 200),
        ]

        var painted = tabbed(pages, selected: 0, changed: 9)
        painted.properties[.barBackgroundColor] = .color(red: 54, green: 42, blue: 86, alpha: 255)
        renderer.applyForTesting(tree(painted))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let row = controller.tabRowForTesting
        let control = row.controlForTesting
        XCTAssertTrue(controller.tabRowStandsInTitleBarForTesting)
        if #available(macOS 26.1, *) {
            XCTAssertEqual(controller.tabRowAccessoryForTesting?.preferredScrollEdgeEffectStyle, .soft)
        }
        XCTAssertEqual(control.trackingMode, .selectOne)
        XCTAssertEqual(control.segmentDistribution, .fillEqually)
        XCTAssertEqual(
            (0..<control.segmentCount).map { control.label(forSegment: $0) },
            ["Home", "Browse"])
        XCTAssertEqual(control.selectedSegment, 0)

        let tabs = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("tabs")) as? AppKitTabView)
        XCTAssertFalse(tabs.showsTabsForTesting)
        XCTAssertNil(tabs.layer?.backgroundColor, "the tab row and the tab view are the system's")

        row.chooseForTesting(1)
        XCTAssertEqual(tabs.selectedIndexForTesting, 1)

        renderer.applyForTesting(tree(tabbed(pages, selected: 1, changed: 9)))
        XCTAssertEqual(control.selectedSegment, 1)
    }

    /// A tab the user chooses changes the window's chrome at once - its
    /// title and its row - whether or not the application binds the selection
    /// and renders again.
    @MainActor
    func testAUserChosenTabRenamesTheWindowAtOnce() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var unbound = tabbed([
            page("home", title: "Home", events: 100),
            page("browse", title: "Browse", events: 200),
        ], selected: 0)
        unbound.events = .replace([:])
        unbound.properties[.selectedTab] = nil
        renderer.applyForTesting(tree(unbound))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        XCTAssertEqual(controller.window?.title, "Home")

        controller.tabRowForTesting.chooseForTesting(1)
        XCTAssertEqual(controller.window?.title, "Browse")
        XCTAssertEqual(controller.tabRowForTesting.controlForTesting.selectedSegment, 1)

        controller.tabRowForTesting.chooseForTesting(0)
        XCTAssertEqual(controller.window?.title, "Home")
    }

    /// A tabbed view pushed onto the stack in a split view's detail keeps below
    /// the row its tabs stand in, and the page left when it is popped rises
    /// back beneath the toolbar: the row coming and going changes the detail's
    /// safe area, and the detail lays its page out again in it.
    @MainActor
    func testATabbedPageOnTheDetailsStackKeepsBelowItsTabRow() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        let menu = page("menu", title: "Menu", events: 100)
        let home = page("home", title: "Home", events: 200)
        renderer.applyForTesting(tree(flyout(
            presented: true, menu: menu, detail: navigation([home])), width: 1200))
        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        window.setContentSize(NSSize(width: 1200, height: 800))
        window.contentView?.layoutSubtreeIfNeeded()

        let pushed = tabbed([
            page("example", title: "Example", events: 300),
            page("code", title: "In Code", events: 400),
        ], selected: 0)
        renderer.applyForTesting(tree(flyout(
            presented: true, menu: menu, detail: navigation([home, pushed])), width: 1200))
        window.contentView?.layoutSubtreeIfNeeded()

        let split = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        let row = try XCTUnwrap(split.detailRowForTesting)
        let rowFrame = row.convert(row.bounds, to: nil)
        let tabs = try XCTUnwrap(renderer.viewForTesting(id: .manual("tabs")))
        XCTAssertGreaterThan(rowFrame.height, 0)
        XCTAssertLessThanOrEqual(
            tabs.convert(tabs.bounds, to: nil).maxY, rowFrame.minY,
            "the pushed tabbed view keeps below its tab row")

        renderer.applyForTesting(tree(flyout(
            presented: true, menu: menu, detail: navigation([home])), width: 1200))
        window.contentView?.layoutSubtreeIfNeeded()
        let shown = try XCTUnwrap(renderer.viewForTesting(id: .manual("home")))
        XCTAssertNil(split.detailRowForTesting)
        XCTAssertGreaterThan(
            shown.convert(shown.bounds, to: nil).maxY, rowFrame.minY,
            "the page left rises back beneath the toolbar")
    }

    /// A tabbed view in a split view's detail shows its tabs in the row
    /// beneath the toolbar - across that column as its own accessory - and a
    /// detail that is no tabbed view takes the row away; a tabbed view in the
    /// sidebar keeps its tabs on its content.
    @MainActor
    func testATabbedDetailShowsItsTabsBeneathTheToolbar() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: page("menu", title: "Menu", events: 100),
            detail: tabbed([
                page("home", title: "Home", events: 200),
                page("browse", title: "Browse", events: 300),
            ], selected: 0))))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let split = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        XCTAssertEqual(controller.tabRowForTesting.controlForTesting.segmentCount, 2)
        XCTAssertTrue(split.detailRowForTesting === controller.tabRowForTesting)
        XCTAssertTrue(controller.tabRowSplitForTesting === split)
        XCTAssertFalse(controller.tabRowStandsInTitleBarForTesting)
        if #available(macOS 26.1, *) {
            XCTAssertEqual(split.detailRowAccessoryForTesting?.preferredScrollEdgeEffectStyle, .soft)
        }

        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: page("menu", title: "Menu", events: 100),
            detail: page("detail", title: "Detail", events: 400))))
        XCTAssertFalse(controller.tabRowStandsInTitleBarForTesting)
        XCTAssertNil(split.detailRowForTesting)

        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: tabbed([
                page("near", title: "Near", events: 500),
                page("far", title: "Far", events: 600),
            ], selected: 0, changed: 904, id: "sidebar-tabs"),
            detail: page("detail", title: "Detail", events: 400))))
        let sidebarTabs = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("sidebar-tabs")) as? AppKitTabView)
        XCTAssertTrue(sidebarTabs.showsTabsForTesting)
        XCTAssertFalse(controller.tabRowStandsInTitleBarForTesting)
    }

    /// A tabbed view in a tab of another is a native tab view with its tabs on
    /// the top edge of its content, named by its pages; a tab clicked there is
    /// the user choosing. The window's toolbar serves only the outer one.
    @MainActor
    func testATabViewInsideATabShowsItsTabsOnItsContent() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(tabbed([
            tabbed([
                page("home", title: "Home", events: 100),
                page("more", title: "More", events: 300),
            ], selected: 0, changed: 903, id: "inner"),
            page("browse", title: "Browse", events: 200),
        ], selected: 0)))

        let inner = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("inner")) as? AppKitTabView)
        let outer = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("tabs")) as? AppKitTabView)
        XCTAssertTrue(inner.showsTabsForTesting)
        XCTAssertEqual(inner.tabLabelsForTesting, ["Home", "More"])
        XCTAssertFalse(outer.showsTabsForTesting)

        inner.selectForTesting(1)
    }

    /// Each of a window's tabs shows its glyph beside its title, the tabs
    /// sharing the row's width equally: the picture as a template the system
    /// tints, at a glyph's height, the tab's own picture left as it is. A tab
    /// is a capsule on macOS 26 and later, and a row across a column is as
    /// tall as its tabs.
    @MainActor
    func testATabShowsItsGlyphBesideItsTitle() {
        let picture = NSImage(size: NSSize(width: 48, height: 48))
        let row = AppKitTabRow(frame: NSRect(x: 0, y: 0, width: 600, height: 40))
        row.apply(AppKitWindowTabs(
            titles: ["Home", "Browse"],
            images: [picture, nil],
            selected: 0,
            select: { _ in }))

        let control = row.controlForTesting
        XCTAssertEqual(control.segmentDistribution, .fillEqually)
        XCTAssertEqual(control.label(forSegment: 0), "Home")
        XCTAssertEqual(control.image(forSegment: 0)?.isTemplate, true)
        XCTAssertEqual(control.image(forSegment: 0)?.size.height, AppKitTabRow.glyphHeight)
        XCTAssertNil(control.image(forSegment: 1))
        XCTAssertFalse(picture.isTemplate)
        XCTAssertEqual(picture.size, NSSize(width: 48, height: 48))
        XCTAssertEqual(row.frame.height, control.fittingSize.height)
        XCTAssertEqual(control.borderShape, .capsule)
    }

    /// A tab is named by the title and the icon of what it shows - a page,
    /// or an arrangement of pages: its caption and its glyph.
    @MainActor
    func testATabIsNamedByTheTitleAndIconOfWhatItShows() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var library = navigation([page("shelf", title: "Shelf", events: 100)])
        library.properties[.title] = .string("Library")
        library.properties[.icon] = .string("books.png")
        var mail = flyout(
            presented: true,
            menu: page("folders", title: "Folders", events: 200),
            detail: page("inbox", title: "Inbox", events: 300))
        mail.properties[.title] = .string("Mail")
        mail.properties[.icon] = .string("mail.png")
        var more = tabbed(
            [page("settings", title: "Settings", events: 400)],
            selected: 0,
            changed: 903,
            id: "more")
        more.properties[.title] = .string("More")
        more.properties[.icon] = .string("more.png")
        var home = page("home", title: "Home", events: 500)
        home.properties[.icon] = .string("home.png")
        renderer.applyForTesting(tree(tabbed([library, mail, more, home], selected: 3)))

        let tabs = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("tabs")) as? AppKitTabView)
        XCTAssertEqual(tabs.tabLabelsForTesting, ["Library", "Mail", "More", "Home"])
        let row = try XCTUnwrap(renderer.windowsForTesting.first).tabRowForTesting.controlForTesting
        XCTAssertEqual(
            (0..<row.segmentCount).map { row.label(forSegment: $0) },
            ["Library", "Mail", "More", "Home"])
        XCTAssertEqual((0..<row.segmentCount).filter { row.image(forSegment: $0) != nil }, [0, 1, 2, 3])
    }

    /// A navigation stack, a tabbed view and a split view carry their
    /// accessibility identifier on the native view that presents them.
    @MainActor
    func testAnArrangementCarriesItsAccessibilityIdentifier() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var stack = navigation([page("shelf", title: "Shelf", events: 100)])
        stack.properties[.accessibilityIdentifier] = .string("arrangement.stack")
        var tabs = tabbed([stack], selected: 0)
        tabs.properties[.accessibilityIdentifier] = .string("arrangement.tabs")
        var split = flyout(
            presented: true,
            menu: page("folders", title: "Folders", events: 200),
            detail: tabs)
        split.properties[.accessibilityIdentifier] = .string("arrangement.split")
        renderer.applyForTesting(tree(split))

        XCTAssertEqual(
            renderer.viewForTesting(id: .manual("navigation"))?.accessibilityIdentifier(),
            "arrangement.stack")
        XCTAssertEqual(
            renderer.viewForTesting(id: .manual("tabs"))?.accessibilityIdentifier(),
            "arrangement.tabs")
        XCTAssertEqual(
            renderer.viewForTesting(id: .manual("flyout"))?.accessibilityIdentifier(),
            "arrangement.split")
    }

    /// A page holds what it shows across all of it and paints its
    /// background colour behind it.
    @MainActor
    func testAPagesContentFillsItAndItsBackgroundReachesItsView() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var painted = HostPatch(id: .manual("painted"), type: .page)
        painted.properties = [.background: .color(red: 51, green: 102, blue: 153, alpha: 255)]
        painted.children = .arranged([HostPatch(id: .manual("content"), type: .colorBox)])
        renderer.applyForTesting(tree(painted))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("painted")))
        let content = try XCTUnwrap(renderer.viewForTesting(id: .manual("content")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()

        XCTAssertEqual(content.frame, native.bounds)
        assertChannels(channels(native.layer?.backgroundColor), [0.2, 0.4, 0.6, 1])
    }

    @MainActor
    func testUserFlyoutToggleReportsItsSettledValueOnce() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(flyout(
            presented: false,
            menu: page("menu", events: 100),
            detail: page("detail", events: 200),
            changed: 9), width: 600))

        let flyout = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        flyout.toggleForTesting()

        XCTAssertTrue(flyout.isEffectivelyPresentedForTesting)
    }

    @MainActor
    func testFlyoutIsPresentedByANativeSplitViewController() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(flyout(
            presented: false,
            menu: page("menu", events: 100),
            detail: page("detail", events: 200)), width: 600))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let content = try XCTUnwrap(controller.window?.contentView)
        let flyout = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        let split = flyout.splitController
        let toolbar = controller.toolbarForTesting
        content.layoutSubtreeIfNeeded()

        XCTAssertTrue(split.view.superview === flyout)
        XCTAssertEqual(split.splitViewItems.count, 2)
        XCTAssertEqual(split.splitViewItems[0].behavior, .sidebar)
        XCTAssertTrue(split.splitViewItems[0].allowsFullHeightLayout)
        XCTAssertTrue(split.splitViewItems[0].canCollapse)
        XCTAssertTrue(split.splitViewItems[0].isCollapsed)
        XCTAssertFalse(split.splitViewItems[1].isCollapsed)
        XCTAssertEqual(flyout.frame, content.bounds)
        XCTAssertTrue(toolbar.sidebarForTesting === split)
        XCTAssertEqual(
            Array(toolbar.identifiersForTesting.prefix(2)),
            [.toggleSidebar, .sidebarTrackingSeparator])
    }

    /// The system toggle hides a sidebar the host showed for a wide window,
    /// and the user's answer stands: nothing forces it back.
    @MainActor
    func testTheUserMayHideTheSidebarOfAWideWindow() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(flyout(
            presented: false,
            menu: page("menu", events: 100),
            detail: page("detail", events: 200),
            changed: 9), width: 900))
        let flyout = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        renderer.windowsForTesting.first?.window?.contentView?.layoutSubtreeIfNeeded()
        XCTAssertTrue(flyout.isEffectivelyPresentedForTesting)

        flyout.toggleForTesting()
        flyout.needsLayout = true
        flyout.layoutSubtreeIfNeeded()

        XCTAssertFalse(flyout.isEffectivelyPresentedForTesting)
    }

    @MainActor
    func testWideFlyoutUsesTheNativeSidebarAndSettlesItsBinding() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(flyout(
            presented: false,
            menu: page("menu", events: 100),
            detail: navigation([page("detail", events: 200)]),
            changed: 9), width: 900))

        let flyout = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        renderer.windowsForTesting.first?.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertTrue(flyout.isEffectivelyPresentedForTesting)
        XCTAssertGreaterThanOrEqual(flyout.sidebarWidthForTesting, 260)
    }

    /// A search field in the title's place stands as the toolbar's own search item's field, which AppKit draws as
    /// its rounded field; any other title view stands as a plain item's view.
    @MainActor
    func testATitleSearchFieldIsTheToolbarsSearchItem() throws {
        let searching = State(wrappedValue: true)
        let renderer = AppKitRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Page").titleView {
                    if searching.wrappedValue { SearchField("").id("query") } else { Text("Title") }
                }
            } destination: { _ in Text("Pushed") }
        }
        defer { renderer.closeForTesting() }
        let toolbar = try XCTUnwrap(renderer.windowsForTesting.first?.toolbarForTesting)
        let search = try XCTUnwrap(renderer.viewForTesting(id: .manual("query")) as? AppKitSearchFieldView)

        let item = try XCTUnwrap(toolbar.itemForTesting(AppKitWindowToolbar.center) as? NSSearchToolbarItem)
        XCTAssertTrue(item.searchField === search, "our field, the search item's")

        searching.wrappedValue = false
        renderer.runtime.pump.turn()
        let plain = try XCTUnwrap(toolbar.itemForTesting(AppKitWindowToolbar.center))
        XCTAssertFalse(plain is NSSearchToolbarItem)
        XCTAssertNotNil(plain.view, "the label's view")
    }

    @MainActor
    func testNavigationUsesThePagesTitleViewAndToolbarItems() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var title = HostPatch(id: .manual("title-label"), type: .text)
        title.properties[.text] = .string("Search title")
        var titleSlot = HostPatch(id: .manual("title-slot"), type: .titleView)
        titleSlot.children = .arranged([title])

        var save = HostPatch(id: .manual("save"), type: .toolbarItem)
        save.properties[.text] = .string("Save")
        save.events = .replace([.clicked: 50])
        var toolbar = HostPatch(id: .manual("toolbar"), type: .toolbarItemGroup)
        toolbar.children = .arranged([save])

        var details = page("details", title: "Ignored", events: 200)
        var content = details.children.arrangedForTesting
        content.append(contentsOf: [titleSlot, toolbar])
        details.children = .arranged(content)

        renderer.applyForTesting(tree(navigation([
            page("home", events: 100),
            details,
        ])))

        let chrome = try XCTUnwrap(renderer.windowsForTesting.first).toolbarForTesting
        let customTitle = try XCTUnwrap(
            chrome.itemForTesting(AppKitWindowToolbar.center)?.view as? AppKitTextView)
        XCTAssertEqual(customTitle.stringValue, "Search title")
        XCTAssertEqual(chrome.actionTitlesForTesting, ["Save"])
        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        XCTAssertEqual(window.title, "Ignored", "the title still names the window")
        XCTAssertEqual(window.titleVisibility, .hidden, "the title view stands in for it")

        let saveItem = try XCTUnwrap(chrome.itemForTesting(titled: "Save"))
        chrome.performForTesting(saveItem.itemIdentifier)
    }

    /// A layout standing in the toolbar stands at the size StateUI measures it at - AppKit measures a toolbar item's
    /// view by Auto Layout and warns of any at nothing - so it stands out of the toolbar while it holds nothing, and
    /// in it once it holds something.
    @MainActor
    func testALayoutInTheToolbarSaysItsSize() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        func details(_ words: [String]) -> HostPatch {
            var row = HostPatch(id: .manual("row"), type: .hStack)
            row.children = .arranged(words.map { word in
                var label = HostPatch(id: .manual(word), type: .text)
                label.properties[.text] = .string(word)
                return label
            })
            var slot = HostPatch(id: .manual("title-slot"), type: .titleView)
            slot.children = .arranged([row])
            var page = page("details", title: "Details", events: 200)
            var content = page.children.arrangedForTesting
            content.append(slot)
            page.children = .arranged(content)
            return page
        }
        renderer.applyForTesting(tree(navigation([page("home", events: 100), details([])])))
        let chrome = try XCTUnwrap(renderer.windowsForTesting.first).toolbarForTesting
        XCTAssertNil(chrome.itemForTesting(AppKitWindowToolbar.center), "nothing held, no item")

        renderer.applyForTesting(tree(navigation([page("home", events: 100), details(["Search", "title"])])))
        let held = try XCTUnwrap(chrome.itemForTesting(AppKitWindowToolbar.center)?.view)
        XCTAssertGreaterThan(held.fittingSize.width, 40, "the words' room")
        XCTAssertGreaterThan(held.fittingSize.height, 10)
    }

    /// The page's actions are native toolbar items: each group by its order,
    /// a space between two groups, a leading group before the flexible space,
    /// and the overflow's behind the toolbar's own overflow menu.
    @MainActor
    func testThePagesGroupsStandInTheToolbarByTheirOrder() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        func toolbarItem(
            _ id: String,
            title: String,
            placement: Int32 = 0,
            enabled: Bool = true,
            destructive: Bool = false,
            icon: String? = nil
        ) -> HostPatch {
            var item = HostPatch(id: .manual(id), type: .toolbarItem)
            item.properties = [
                .text: .string(title),
                .placement: .enumeration(placement),
                .isEnabled: .bool(enabled),
                .isDestructive: .bool(destructive),
            ]
            if let icon { item.properties[.icon] = .string(icon) }
            return item
        }
        func group(_ id: String, order: Double, side: ToolbarSide = .trailing, _ items: [HostPatch]) -> HostPatch {
            var group = HostPatch(id: .manual(id), type: .toolbarItemGroup)
            group.properties = [.order: .number(order), .side: .enumeration(side.rawValue)]
            group.children = .arranged(items)
            return group
        }

        var details = page("details", title: "Details", events: 200)
        details.children = .arranged(details.children.arrangedForTesting + [
            group("later", order: 1, [
                toolbarItem("save", title: "Save", enabled: false, icon: "save-symbol"),
                toolbarItem("delete", title: "Delete", placement: 2, destructive: true),
            ]),
            group("first", order: 0, [toolbarItem("earlier", title: "Earlier")]),
            group("start", order: 0, side: .leading, [toolbarItem("compose", title: "Compose")]),
        ])
        var stack = navigation([
            page("home", title: "Home", events: 100),
            details,
        ])
        stack.properties[.barForegroundColor] = .color(
            red: 51, green: 179, blue: 230, alpha: 255)
        renderer.applyForTesting(tree(stack))

        let chrome = try XCTUnwrap(renderer.windowsForTesting.first).toolbarForTesting
        let save = try XCTUnwrap(chrome.itemForTesting(titled: "Save"))
        let earlier = try XCTUnwrap(chrome.itemForTesting(titled: "Earlier"))
        let compose = try XCTUnwrap(chrome.itemForTesting(titled: "Compose"))
        let identifiers = chrome.identifiersForTesting

        XCTAssertEqual(chrome.actionTitlesForTesting, ["Compose", "Earlier", "Save"])
        XCTAssertEqual(chrome.overflowTitlesForTesting, ["Delete"])
        XCTAssertLessThan(
            try XCTUnwrap(identifiers.firstIndex(of: compose.itemIdentifier)),
            try XCTUnwrap(identifiers.firstIndex(of: .flexibleSpace)), "the leading group before the flexible space")
        let from = try XCTUnwrap(identifiers.firstIndex(of: earlier.itemIdentifier))
        let to = try XCTUnwrap(identifiers.firstIndex(of: save.itemIdentifier))
        XCTAssertEqual(identifiers[from...to].filter { $0 == .space }.count, 1, "a space between two groups")
        XCTAssertNil(chrome.itemForTesting(titled: "Delete"))
        XCTAssertNotNil(chrome.itemForTesting(AppKitWindowToolbar.overflow))
        XCTAssertFalse(save.isEnabled)
        XCTAssertNotNil(save.image)
        XCTAssertTrue(save.isBordered)
        XCTAssertEqual(earlier.title, "Earlier")
        XCTAssertTrue(earlier.isBordered)
    }

    @MainActor
    func testVisiblePageBuildsNativeNestedMenuItems() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var save = HostPatch(id: .manual("save"), type: .menuItem)
        save.properties[.text] = .string("Save")
        save.events = .replace([.clicked: 60])
        let separator = HostPatch(id: .manual("separator"), type: .divider)
        var recentFile = HostPatch(id: .manual("recent-file"), type: .menuItem)
        recentFile.properties[.text] = .string("notes.txt")
        var recent = HostPatch(id: .manual("recent"), type: .menu)
        recent.properties[.text] = .string("Recent")
        recent.children = .arranged([recentFile])
        var file = HostPatch(id: .manual("file"), type: .menu)
        file.properties[.text] = .string("File")
        file.children = .arranged([save, separator, recent])
        var menus = HostPatch(id: .manual("menus"), type: .menuBar)
        menus.children = .arranged([file])

        var details = page("details", events: 200)
        var content = details.children.arrangedForTesting
        content.append(menus)
        details.children = .arranged(content)

        renderer.applyForTesting(tree(navigation([
            page("home", events: 100),
            details,
        ])))

        let menu = try XCTUnwrap(renderer.windowsForTesting.first?.pageMenuItemsForTesting.first)
        XCTAssertEqual(menu.title, "File")
        XCTAssertEqual(menu.submenu?.items.map(\.title), ["Save", "", "Recent"])
        XCTAssertEqual(menu.submenu?.items.last?.submenu?.items.map(\.title), ["notes.txt"])

        menu.submenu?.performActionForItem(at: 0)
    }

    @MainActor
    func testModalStackMovesVisibilityBetweenRootAndTopSheet() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(page("root", events: 100)))

        renderer.applyForTesting(tree(
            page("root", events: 100),
            modals: [page("sheet", events: 200)]))
        XCTAssertEqual(renderer.windowsForTesting.first?.modalCountForTesting, 1)

        renderer.applyForTesting(tree(
            page("root", events: 100),
            modals: [page("sheet", events: 200), page("about", events: 300)]))

        renderer.applyForTesting(tree(page("root", events: 100), modals: []))
        XCTAssertEqual(renderer.windowsForTesting.first?.modalCountForTesting, 0)
    }

    /// A page that takes its way back away offers none in the window's
    /// toolbar, where the page beneath it offered one.
    @MainActor
    func testAPageWithoutABackButtonOffersNoWayBack() throws {
        let path = State(wrappedValue: [ChromeRoute]())
        let renderer = AppKitRenderer.running {
            NavigationStack(path.projectedValue) {
                Text("Root")
            } destination: { route in
                ChromePage(route: route)
            }
        }
        defer { renderer.closeForTesting() }
        let toolbar = try XCTUnwrap(renderer.windowsForTesting.first).toolbarForTesting

        path.wrappedValue = [.plain]
        renderer.runtime.pump.turn()
        XCTAssertNotNil(toolbar.itemForTesting(AppKitWindowToolbar.back), "an ordinary page")

        path.wrappedValue = [.plain, .withoutBackButton]
        renderer.runtime.pump.turn()
        XCTAssertNil(toolbar.itemForTesting(AppKitWindowToolbar.back))
    }

    /// A page without a navigation bar puts neither its way back nor its
    /// actions in the window's toolbar, where the page beneath it showed
    /// both.
    @MainActor
    func testAPageWithoutANavigationBarKeepsItsWayBackAndActionsOutOfTheToolbar() throws {
        let path = State(wrappedValue: [ChromeRoute]())
        let renderer = AppKitRenderer.running {
            NavigationStack(path.projectedValue) {
                Text("Root")
            } destination: { route in
                ChromePage(route: route)
            }
        }
        defer { renderer.closeForTesting() }
        let toolbar = try XCTUnwrap(renderer.windowsForTesting.first).toolbarForTesting

        path.wrappedValue = [.plain]
        renderer.runtime.pump.turn()
        XCTAssertNotNil(toolbar.itemForTesting(AppKitWindowToolbar.back), "an ordinary page")
        XCTAssertEqual(toolbar.actionTitlesForTesting, ["Save"], "an ordinary page")

        path.wrappedValue = [.plain, .withoutNavigationBar]
        renderer.runtime.pump.turn()
        XCTAssertNil(toolbar.itemForTesting(AppKitWindowToolbar.back))
        XCTAssertEqual(toolbar.actionTitlesForTesting, [])
    }
}

/// What a pushed page asks of the navigation furniture above it.
private enum ChromeRoute: Hashable {
    case plain
    case withoutBackButton
    case withoutNavigationBar
}

/// A pushed page that declares one action and, for its route, takes its way
/// back or its whole navigation bar away.
private struct ChromePage: View {
    let route: ChromeRoute

    var body: some View {
        Text("Pushed").toolbar { ToolbarItem("Save") }
            .showsBackButton(route != .withoutBackButton)
            .showsNavigationBar(route != .withoutNavigationBar)
    }
}

private extension AppKitPageTests {
    func tree(_ page: HostPatch, width: Double? = nil) -> HostPatch {
        tree(page, modals: nil, width: width)
    }

    func tree(
        _ page: HostPatch,
        modals: [HostPatch]?,
        width: Double? = nil
    ) -> HostPatch {
        var window = HostPatch(id: .manual("window"), type: .window)
        if let width { window.properties[.width] = .number(width) }
        if let modals {
            // The window's page is a modal stack: the page it holds, then its sheets.
            var stack = HostPatch(id: .manual("modals"), type: .modalStack)
            stack.children = .arranged([page] + modals)
            stack.events = .replace([.popped: 902])
            window.children = .arranged([stack])
        } else {
            window.children = .arranged([page])
        }

        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])

        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }

    func navigation(_ pages: [HostPatch], popped: Int32 = 900) -> HostPatch {
        var navigation = HostPatch(id: .manual("navigation"), type: .navigationStack)
        navigation.events = .replace([.popped: popped])
        navigation.children = .arranged(pages)
        return navigation
    }

    func tabbed(
        _ pages: [HostPatch],
        selected: Int,
        changed: Int32 = 901,
        id: String = "tabs"
    ) -> HostPatch {
        var tabs = HostPatch(id: .manual(id), type: .tabView)
        tabs.properties[.selectedTab] = .number(Double(selected))
        tabs.events = .replace([.selectedTabChanged: changed])
        tabs.children = .arranged(pages)
        return tabs
    }

    func flyout(
        presented: Bool,
        menu: HostPatch,
        detail: HostPatch,
        changed: Int32 = 902
    ) -> HostPatch {
        var flyout = HostPatch(id: .manual("flyout"), type: .splitView)
        flyout.properties[.showsSidebar] = .bool(presented)
        flyout.events = .replace([.showsSidebarChanged: changed])
        flyout.children = .arranged([menu, detail])
        return flyout
    }

    func page(_ id: String, title: String? = nil, events base: Int32) -> HostPatch {
        var label = HostPatch(id: .manual("label-\(id)"), type: .text)
        label.properties[.text] = .string(id)

        var page = HostPatch(id: .manual(id), type: .page)
        if let title { page.properties[.title] = .string(title) }
        page.events = .replace([
            .appearing: base,
            .disappearing: base + 1,
            .navigatedTo: base + 2,
            .navigatingFrom: base + 3,
            .navigatedFrom: base + 4,
        ])
        page.children = .arranged([label])
        return page
    }

    /// One window holding `content`, asked - or, given nil, no longer asked -
    /// to let the desktop show through it.
    func windowTree(_ content: HostPatch, translucent: Bool?, background: HostValue? = nil) -> HostPatch {
        var window = HostPatch(id: .manual("window"), type: .window)
        if let translucent {
            window.properties[.isTranslucent] = .bool(translucent)
        } else {
            window.properties[.isTranslucent] = .nothing
        }
        window.properties[.background] = background ?? .nothing
        window.children = .arranged([content])

        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])

        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }

    func page(_ id: String, title: String) -> HostPatch {
        page(id, title: title, events: 1_000)
    }
}

private extension HostChildrenUpdate {
    var arrangedForTesting: [HostPatch] {
        guard case .arranged(let children) = self else { return [] }
        return children
    }
}

#endif
