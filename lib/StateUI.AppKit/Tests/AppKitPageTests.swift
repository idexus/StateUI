// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitPageTests: XCTestCase {
    @MainActor
    func testAWindowPresentsItsContentPageExactlyOnce() {
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
        home.properties[.navigationPageBackButtonTitle] = .string("Start")
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
    /// background. A bar colour is the platform's to adapt, and AppKit keeps
    /// its toolbar's own material.
    @MainActor
    func testANavigationStackStandsUnderTheWindowsNativeToolbar() throws {
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

    @MainActor
    func testTabbedPageAppliesAndClearsItsFlatBarBackground() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }
        let authored = NSColor(
            srgbRed: 54.0 / 255.0,
            green: 42.0 / 255.0,
            blue: 86.0 / 255.0,
            alpha: 1)

        var tabsPatch = tabbed([
            page("home", events: 100),
            page("browse", events: 200),
        ], selected: 0)
        tabsPatch.properties[.barBackgroundColor] = .color(
            red: 54, green: 42, blue: 86, alpha: 255)
        renderer.applyForTesting(tree(tabsPatch))

        let tabs = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("tabs")) as? AppKitTabbedView)
        XCTAssertTrue(tabs.barBackgroundColorForTesting?.isEqual(authored) == true)

        var cleared = tabbed([
            page("home", events: 100),
            page("browse", events: 200),
        ], selected: 0)
        cleared.clearedProperties = [.barBackgroundColor]
        renderer.applyForTesting(tree(cleared))

        XCTAssertNil(tabs.barBackgroundColorForTesting)
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
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitFlyoutView)
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
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitFlyoutView)
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
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitFlyoutView)
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
            renderer.viewForTesting(id: .manual("flyout")) as? AppKitFlyoutView)
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
        var titleSlot = HostPatch(id: .manual("title-slot"), type: .navigationPageTitleView)
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
                .order: .enumeration(order),
                .isEnabled: .bool(enabled),
                .isDestructive: .bool(destructive),
            ]
            if let icon { item.properties[.iconImageSource] = .string(icon) }
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

        var save = HostPatch(id: .manual("save"), type: .menuFlyoutItem)
        save.properties[.text] = .string("Save")
        save.events = .replace([.clicked: 60])
        let separator = HostPatch(id: .manual("separator"), type: .menuFlyoutSeparator)
        var recentFile = HostPatch(id: .manual("recent-file"), type: .menuFlyoutItem)
        recentFile.properties[.text] = .string("notes.txt")
        var recent = HostPatch(id: .manual("recent"), type: .menuFlyoutSubItem)
        recent.properties[.text] = .string("Recent")
        recent.children = .arranged([recentFile])
        var file = HostPatch(id: .manual("file"), type: .menuBarItem)
        file.properties[.text] = .string("File")
        file.children = .arranged([save, separator, recent])
        var menus = HostPatch(id: .manual("menus"), type: .menuBarItems)
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
        var navigation = HostPatch(id: .manual("navigation"), type: .navigationPage)
        navigation.events = .replace([.popped: popped])
        navigation.children = .arranged(pages)
        return navigation
    }

    func tabbed(
        _ pages: [HostPatch],
        selected: Int,
        changed: Int32 = 901
    ) -> HostPatch {
        var tabs = HostPatch(id: .manual("tabs"), type: .tabbedPage)
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
        var flyout = HostPatch(id: .manual("flyout"), type: .flyoutPage)
        flyout.properties[.isPresented] = .bool(presented)
        flyout.events = .replace([.isPresentedChanged: changed])
        flyout.children = .arranged([menu, detail])
        return flyout
    }

    func page(_ id: String, title: String? = nil, events base: Int32) -> HostPatch {
        var label = HostPatch(id: .manual("label-\(id)"), type: .label)
        label.properties[.text] = .string(id)

        var page = HostPatch(id: .manual(id), type: .contentPage)
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
