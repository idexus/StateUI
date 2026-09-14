// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitPageTests: XCTestCase {
    @MainActor
    func testAWindowPresentsItsPageExactlyOnce() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(page("home", events: 100)))
        renderer.applyForTesting(tree(page("home", events: 100)))

        XCTAssertEqual(reported.map(\.0), [100])
    }

    @MainActor
    func testNavigationMovesReportEachPagePhaseInDeterministicOrder() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(navigation([
            page("home", events: 100),
        ])))
        XCTAssertEqual(reported.map(\.0), [100, 102])

        reported.removeAll()
        renderer.applyForTesting(tree(navigation([
            page("home", events: 100),
            page("details", events: 200),
        ])))
        XCTAssertEqual(reported.map(\.0), [103, 101, 104, 200, 202])

        reported.removeAll()
        renderer.applyForTesting(tree(navigation([
            page("home", events: 100),
        ])))
        XCTAssertEqual(reported.map(\.0), [203, 201, 204, 100, 102])
    }

    @MainActor
    func testNavigationBackReportsTheCommittedSurvivingDepth() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(navigation([
            page("home", events: 100),
            page("one", events: 200),
            page("two", events: 300),
        ], popped: 9)))
        reported.removeAll()

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        controller.toolbarForTesting.performForTesting(AppKitWindowToolbar.back)

        XCTAssertEqual(reported.count, 1)
        XCTAssertEqual(reported[0].0, 9)
        XCTAssertEqual(reported[0].1, [.number(1)])
    }

    /// The top page names the window, and the way back is the system's
    /// navigational toolbar item, labelled by the page it returns to.
    @MainActor
    func testTheWindowToolbarCarriesTheTopPageAndTheWayBack() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
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
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
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
    /// above the page, and the title bar lets it show. The window keeps its
    /// own background, and a colour taken away gives the material back.
    @MainActor
    func testAWrittenBarColourPaintsTheBandAboveThePage() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
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
        XCTAssertTrue(window.backgroundColor.isEqual(NSColor.windowBackgroundColor))

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
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertNil(toolbar.itemForTesting(AppKitWindowToolbar.title))
    }

    /// In a split view the band is the detail's: the pane under the bars
    /// paints it, and the sidebar keeps its own glass.
    @MainActor
    func testAWrittenBarColourPaintsOnlyTheSplitDetailsBand() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
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
        XCTAssertNil(content.barColor, "the split view covers the window's own band")
    }

    @MainActor
    func testTabSelectionChangesVisibilityWithoutInventingNavigation() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(tabbed([
            page("home", events: 100),
            page("browse", events: 200),
        ], selected: 0)))
        XCTAssertEqual(reported.map(\.0), [100])

        reported.removeAll()
        renderer.applyForTesting(tree(tabbed([
            page("home", events: 100),
            page("browse", events: 200),
        ], selected: 1)))
        XCTAssertEqual(reported.map(\.0), [101, 200])
    }

    @MainActor
    func testReaderTabSelectionReportsTheSelectedIndexOnce() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(tabbed([
            page("home", title: "Home", events: 100),
            page("browse", title: "Browse", events: 200),
        ], selected: 0, changed: 9)))
        reported.removeAll()

        let tabs = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("tabs")) as? AppKitTabbedView)
        tabs.selectForTesting(1)

        XCTAssertEqual(reported.count, 3)
        XCTAssertEqual(reported.map(\.0), [101, 200, 9])
        XCTAssertEqual(reported.last?.1, [.number(1)])
        XCTAssertEqual(tabs.selectedIndexForTesting, 1)
    }

    /// A tabbed view on the window's page path shows its tabs in a row
    /// beneath the window's toolbar - beneath the title bar where there is no
    /// split view - one select-one segmented control sharing the width
    /// equally, and none on its content, where nothing is painted. Choosing in
    /// the row is the reader choosing.
    @MainActor
    func testAWindowsTabbedViewSelectsFromTheRowBeneathItsToolbar() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }
        let pages = [
            page("home", title: "Home", events: 100),
            page("browse", title: "Browse", events: 200),
        ]

        var painted = tabbed(pages, selected: 0, changed: 9)
        painted.properties[.barBackgroundColor] = .color(red: 54, green: 42, blue: 86, alpha: 255)
        renderer.applyForTesting(tree(painted))
        reported.removeAll()

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
            renderer.viewForTesting(id: .manual("tabs")) as? AppKitTabbedView)
        XCTAssertFalse(tabs.showsTabsForTesting)
        XCTAssertNil(tabs.layer?.backgroundColor, "the tab row and the tab view are the system's")

        row.chooseForTesting(1)
        XCTAssertEqual(reported.map(\.0), [101, 200, 9])
        XCTAssertEqual(reported.last?.1, [.number(1)])
        XCTAssertEqual(tabs.selectedIndexForTesting, 1)

        renderer.applyForTesting(tree(tabbed(pages, selected: 1, changed: 9)))
        XCTAssertEqual(control.selectedSegment, 1)
    }

    /// A tab the reader chooses changes the window's chrome at once - its
    /// title and its row - whether or not the application binds the selection
    /// and renders again.
    @MainActor
    func testAReaderChosenTabRenamesTheWindowAtOnce() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        var unbound = tabbed([
            page("home", title: "Home", events: 100),
            page("browse", title: "Browse", events: 200),
        ], selected: 0)
        unbound.events = .replace([:])
        unbound.properties[.currentPage] = nil
        renderer.applyForTesting(tree(unbound))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        XCTAssertEqual(controller.window?.title, "Home")

        controller.tabRowForTesting.chooseForTesting(1)
        XCTAssertEqual(controller.window?.title, "Browse")
        XCTAssertEqual(controller.tabRowForTesting.controlForTesting.selectedSegment, 1)

        controller.tabRowForTesting.chooseForTesting(0)
        XCTAssertEqual(controller.window?.title, "Home")
    }

    /// A tabbed view in a split view's detail shows its tabs in the row
    /// beneath the toolbar - across that column as its own accessory on macOS
    /// 26 and later, beneath the title bar before - and a detail that is no
    /// tabbed view takes the row away; a tabbed view in the sidebar keeps its
    /// tabs on its content.
    @MainActor
    func testATabbedDetailShowsItsTabsBeneathTheToolbar() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
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
        if #available(macOS 26, *) {
            XCTAssertTrue(split.detailRowForTesting === controller.tabRowForTesting)
            XCTAssertTrue(controller.tabRowSplitForTesting === split)
            XCTAssertFalse(controller.tabRowStandsInTitleBarForTesting)
        }
        if #available(macOS 26.1, *) {
            XCTAssertEqual(split.detailRowAccessoryForTesting?.preferredScrollEdgeEffectStyle, .soft)
        }
        if #unavailable(macOS 26) {
            XCTAssertTrue(controller.tabRowStandsInTitleBarForTesting)
        }

        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: page("menu", title: "Menu", events: 100),
            detail: page("detail", title: "Detail", events: 400))))
        XCTAssertFalse(controller.tabRowStandsInTitleBarForTesting)
        if #available(macOS 26, *) {
            XCTAssertNil(split.detailRowForTesting)
        }

        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: tabbed([
                page("near", title: "Near", events: 500),
                page("far", title: "Far", events: 600),
            ], selected: 0, changed: 904, id: "sidebar-tabs"),
            detail: page("detail", title: "Detail", events: 400))))
        let sidebarTabs = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("sidebar-tabs")) as? AppKitTabbedView)
        XCTAssertTrue(sidebarTabs.showsTabsForTesting)
        XCTAssertFalse(controller.tabRowStandsInTitleBarForTesting)
    }

    /// A tabbed view in a tab of another is a native tab view with its tabs on
    /// the top edge of its content, named by its pages; a tab clicked there is
    /// the reader choosing. The window's toolbar serves only the outer one.
    @MainActor
    func testATabbedViewInsideATabShowsItsTabsOnItsContent() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(tabbed([
            tabbed([
                page("home", title: "Home", events: 100),
                page("more", title: "More", events: 300),
            ], selected: 0, changed: 903, id: "inner"),
            page("browse", title: "Browse", events: 200),
        ], selected: 0)))
        reported.removeAll()

        let inner = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("inner")) as? AppKitTabbedView)
        let outer = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("tabs")) as? AppKitTabbedView)
        XCTAssertTrue(inner.showsTabsForTesting)
        XCTAssertEqual(inner.tabLabelsForTesting, ["Home", "More"])
        XCTAssertFalse(outer.showsTabsForTesting)

        inner.selectForTesting(1)
        XCTAssertEqual(reported.map(\.0), [101, 300, 903])
        XCTAssertEqual(reported.last?.1, [.number(1)])
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
        if #available(macOS 26, *) {
            XCTAssertEqual(control.borderShape, .capsule)
        }
    }

    @MainActor
    func testChangingAHiddenTabStackReportsNoPageLifecycle() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(navigation([
            tabbed([
                page("home", events: 100),
                page("browse", events: 200),
            ], selected: 0),
            page("details", events: 300),
        ])))
        reported.removeAll()

        renderer.applyForTesting(tree(navigation([
            tabbed([
                page("home", events: 100),
                page("browse", events: 200),
            ], selected: 1),
            page("details", events: 300),
        ])))

        XCTAssertTrue(reported.isEmpty)
    }

    @MainActor
    func testFlyoutVisibilityDoesNotRecreateOrHideItsDetail() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(flyout(
            presented: false,
            menu: page("menu", events: 100),
            detail: page("detail", events: 200))))
        XCTAssertEqual(reported.map(\.0), [200])

        reported.removeAll()
        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: page("menu", events: 100),
            detail: page("detail", events: 200))))
        XCTAssertEqual(reported.map(\.0), [100])

        reported.removeAll()
        renderer.applyForTesting(tree(flyout(
            presented: false,
            menu: page("menu", events: 100),
            detail: page("detail", events: 200))))
        XCTAssertEqual(reported.map(\.0), [101])
    }

    /// A split view whose detail is REPLACED - a stack giving way to a tabbed
    /// view, the way a section changes its arrangement - presents the new
    /// tree: the old detail's page leaves, the selected tab's page arrives,
    /// and a push on that tab's stack reports its phases.
    @MainActor
    func testAReplacedSplitDetailIsPresented() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(flyout(
            presented: false,
            menu: page("menu", events: 100),
            detail: navigation([page("home", events: 200)]))))
        reported.removeAll()

        renderer.applyForTesting(tree(flyout(
            presented: false,
            menu: page("menu", events: 100),
            detail: tabbed([navigation([page("tab", events: 300)])], selected: 0))))
        XCTAssertEqual(reported.map(\.0), [201, 300])

        reported.removeAll()
        renderer.applyForTesting(tree(flyout(
            presented: false,
            menu: page("menu", events: 100),
            detail: tabbed([navigation([
                page("tab", events: 300),
                page("level", events: 400),
            ])], selected: 0))))
        XCTAssertEqual(reported.map(\.0), [303, 301, 304, 400, 402])
    }

    /// The same for the sidebar: one replaced while it shows is presented.
    @MainActor
    func testAReplacedVisibleSidebarIsPresented() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: page("menu", events: 100),
            detail: page("detail", events: 200))))
        reported.removeAll()

        renderer.applyForTesting(tree(flyout(
            presented: true,
            menu: page("sections", events: 500),
            detail: page("detail", events: 200))))
        XCTAssertEqual(reported.map(\.0), [101, 500])
    }

    @MainActor
    func testReaderFlyoutToggleReportsItsSettledValueOnce() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(flyout(
            presented: false,
            menu: page("menu", events: 100),
            detail: page("detail", events: 200),
            changed: 9), width: 600))
        reported.removeAll()

        let flyout = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitSplitView)
        flyout.toggleForTesting()

        XCTAssertEqual(reported.map(\.0), [100, 9])
        XCTAssertEqual(reported.last?.1, [.bool(true)])
        XCTAssertTrue(flyout.isEffectivelyPresentedForTesting)
    }

    @MainActor
    func testFlyoutIsPresentedByANativeSplitViewController() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
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
    /// and the reader's answer stands: nothing forces it back.
    @MainActor
    func testTheReaderMayHideTheSidebarOfAWideWindow() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
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
        reported.removeAll()

        flyout.toggleForTesting()
        flyout.needsLayout = true
        flyout.layoutSubtreeIfNeeded()

        XCTAssertFalse(flyout.isEffectivelyPresentedForTesting)
        XCTAssertEqual(reported.filter { $0.0 == 9 }.map(\.1), [[.bool(false)]])
    }

    @MainActor
    func testWideFlyoutUsesTheNativeSidebarAndSettlesItsBinding() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
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
        XCTAssertTrue(reported.contains { $0.0 == 9 && $0.1 == [.bool(true)] })
    }

    @MainActor
    func testNavigationUsesThePagesTitleViewAndToolbarItems() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        var title = HostPatch(id: .manual("title-label"), type: .label)
        title.properties[.text] = .string("Search title")
        var titleSlot = HostPatch(id: .manual("title-slot"), type: .titleView)
        titleSlot.children = .arranged([title])

        var save = HostPatch(id: .manual("save"), type: .toolbarItem)
        save.properties[.text] = .string("Save")
        save.events = .replace([.clicked: 50])
        var toolbar = HostPatch(id: .manual("toolbar"), type: .toolbarItems)
        toolbar.children = .arranged([save])

        var details = page("details", title: "Ignored", events: 200)
        var content = details.children.arrangedForTesting
        content.append(contentsOf: [titleSlot, toolbar])
        details.children = .arranged(content)

        renderer.applyForTesting(tree(navigation([
            page("home", events: 100),
            details,
        ])))
        reported.removeAll()

        let chrome = try XCTUnwrap(renderer.windowsForTesting.first).toolbarForTesting
        let customTitle = try XCTUnwrap(
            chrome.itemForTesting(AppKitWindowToolbar.center)?.view as? AppKitLabelView)
        XCTAssertEqual(customTitle.stringValue, "Search title")
        XCTAssertEqual(chrome.actionTitlesForTesting, ["Save"])
        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        XCTAssertEqual(window.title, "Ignored", "the title still names the window")
        XCTAssertEqual(window.titleVisibility, .hidden, "the title view stands in for it")

        let saveItem = try XCTUnwrap(chrome.itemForTesting(titled: "Save"))
        chrome.performForTesting(saveItem.itemIdentifier)
        XCTAssertEqual(reported.map(\.0), [50])
    }

    /// The page's actions are native toolbar items: the primary ones by
    /// priority, then source order, and the secondary ones behind the
    /// toolbar's own overflow menu.
    @MainActor
    func testThePagesActionsFollowTheirOrderAndPriorityInTheToolbar() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }

        func toolbarItem(
            _ id: String,
            title: String,
            priority: Int,
            order: Int32 = 0,
            enabled: Bool = true,
            destructive: Bool = false,
            icon: String? = nil
        ) -> HostPatch {
            var item = HostPatch(id: .manual(id), type: .toolbarItem)
            item.properties = [
                .text: .string(title),
                .priority: .number(Double(priority)),
                .placement: .enumeration(order),
                .isEnabled: .bool(enabled),
                .isDestructive: .bool(destructive),
            ]
            if let icon { item.properties[.icon] = .string(icon) }
            return item
        }

        var toolbar = HostPatch(id: .manual("toolbar"), type: .toolbarItems)
        toolbar.children = .arranged([
            toolbarItem(
                "save", title: "Save", priority: 5, enabled: false,
                icon: "save-symbol"),
            toolbarItem("earlier", title: "Earlier", priority: -1),
            toolbarItem(
                "delete", title: "Delete", priority: 0, order: 2,
                destructive: true),
        ])
        var details = page("details", title: "Details", events: 200)
        details.children = .arranged(details.children.arrangedForTesting + [toolbar])
        var stack = navigation([
            page("home", title: "Home", events: 100),
            details,
        ])
        stack.properties[.barTextColor] = .color(
            red: 51, green: 179, blue: 230, alpha: 255)
        renderer.applyForTesting(tree(stack))

        let chrome = try XCTUnwrap(renderer.windowsForTesting.first).toolbarForTesting
        let save = try XCTUnwrap(chrome.itemForTesting(titled: "Save"))
        let earlier = try XCTUnwrap(chrome.itemForTesting(titled: "Earlier"))

        XCTAssertEqual(chrome.actionTitlesForTesting, ["Earlier", "Save"])
        XCTAssertEqual(chrome.overflowTitlesForTesting, ["Delete"])
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
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        var save = HostPatch(id: .manual("save"), type: .menuItem)
        save.properties[.text] = .string("Save")
        save.events = .replace([.clicked: 60])
        let separator = HostPatch(id: .manual("separator"), type: .menuSeparator)
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
        reported.removeAll()

        let menu = try XCTUnwrap(renderer.windowsForTesting.first?.pageMenuItemsForTesting.first)
        XCTAssertEqual(menu.title, "File")
        XCTAssertEqual(menu.submenu?.items.map(\.title), ["Save", "", "Recent"])
        XCTAssertEqual(menu.submenu?.items.last?.submenu?.items.map(\.title), ["notes.txt"])

        menu.submenu?.performActionForItem(at: 0)
        XCTAssertEqual(reported.map(\.0), [60])
    }

    @MainActor
    func testModalStackMovesVisibilityBetweenRootAndTopSheet() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(page("root", events: 100)))
        reported.removeAll()

        renderer.applyForTesting(tree(
            page("root", events: 100),
            modals: [page("sheet", events: 200)]))
        XCTAssertEqual(reported.map(\.0), [103, 101, 104, 200, 202])
        XCTAssertEqual(renderer.windowsForTesting.first?.modalCountForTesting, 1)

        reported.removeAll()
        renderer.applyForTesting(tree(
            page("root", events: 100),
            modals: [page("sheet", events: 200), page("about", events: 300)]))
        XCTAssertEqual(reported.map(\.0), [203, 201, 204, 300, 302])

        reported.removeAll()
        renderer.applyForTesting(tree(page("root", events: 100), modals: []))
        XCTAssertEqual(reported.map(\.0), [303, 301, 304, 100, 102])
        XCTAssertEqual(renderer.windowsForTesting.first?.modalCountForTesting, 0)
    }

    @MainActor
    func testReaderDismissalReportsTheSurvivingModalDepth() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(
            page("root", events: 100),
            modals: [page("sheet", events: 200), page("about", events: 300)],
            modalPopped: 9))
        reported.removeAll()

        let window = try XCTUnwrap(renderer.windowsForTesting.first)
        window.dismissTopModalForTesting()

        XCTAssertEqual(reported.map(\.0), [303, 301, 304, 200, 202, 9])
        XCTAssertEqual(reported.last?.1, [.number(1)])
        XCTAssertEqual(window.modalCountForTesting, 1)
    }
}

private extension AppKitPageTests {
    func tree(_ page: HostPatch, width: Double? = nil) -> HostPatch {
        tree(page, modals: nil, width: width)
    }

    func tree(
        _ page: HostPatch,
        modals: [HostPatch]?,
        modalPopped: Int32 = 902,
        width: Double? = nil
    ) -> HostPatch {
        var window = HostPatch(id: .manual("window"), type: .window)
        if let width { window.properties[.width] = .number(width) }
        if let modals {
            var stack = HostPatch(id: .manual("modals"), type: .modalStack)
            stack.children = .arranged(modals)
            window.children = .arranged([page, stack])
            window.events = .replace([.modalPopped: modalPopped])
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
        var tabs = HostPatch(id: .manual(id), type: .tabbedView)
        tabs.properties[.currentPage] = .number(Double(selected))
        tabs.events = .replace([.currentPageChanged: changed])
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
        flyout.properties[.isSidebarVisible] = .bool(presented)
        flyout.events = .replace([.isSidebarVisibleChanged: changed])
        flyout.children = .arranged([menu, detail])
        return flyout
    }

    func page(_ id: String, title: String? = nil, events base: Int32) -> HostPatch {
        var label = HostPatch(id: .manual("label-\(id)"), type: .label)
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
