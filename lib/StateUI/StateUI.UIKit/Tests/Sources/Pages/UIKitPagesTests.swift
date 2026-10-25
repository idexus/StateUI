// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance
import XCTest

/// What pages and their arrangements say on UIKit's bars and the window's scene.
@MainActor
final class UIKitPagesTests: XCTestCase {
    /// Tabs pushed onto a stack are its last place and name the window by their own title, on the bar and the
    /// scene alike - never by what they show: their pages name their tabs alone.
    @MainActor
    func testTabsOnAStackNameTheWindowByTheirOwnTitle() throws {
        let path = State(wrappedValue: [Int]())
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(path.projectedValue) {
                TitledPage(title: "Items and Cards")
            } destination: { _ in
                TabView([1, 2]) { number in TitledPage(title: "Example \(number)") }.title("ItemsView")
            }
        }
        defer { host.finish() }
        let window: UIWindow = try XCTUnwrap(host.roster.windows.first?.1.window)
        host.settle { window.windowScene?.title == "Items and Cards" }
        XCTAssertEqual(window.windowScene?.title, "Items and Cards")

        path.wrappedValue = [1]
        let pushed: () -> UIViewController? = {
            (host.runtime.tree.root.flatMap { Self.tabView(in: $0) }?.native as? UIKitElement)?.controller
        }
        host.settle { pushed() != nil }
        host.runtime.pump.turn()
        let tabs: UIViewController = try XCTUnwrap(pushed())
        XCTAssertEqual(tabs.navigationItem.title, "ItemsView", "the bar's title")
        XCTAssertEqual(window.windowScene?.title, "ItemsView", "the scene's")
    }

    /// Pages joining on top move in as one push, however many join, and pages taken from the top move back as one
    /// pop, however many go; a page under the top replaced shows without a move.
    @MainActor
    func testSeveralPagesMoveAsOnePushOrOnePop() throws {
        let path = State(wrappedValue: [Int]())
        let host = UIKitRenderer.running {
            NavigationStack(path.projectedValue) {
                Text("Root")
            } destination: { level in
                Text("Level \(level)")
            }
        }
        defer { host.finish() }
        let stack = try XCTUnwrap(host.runtime.tree.root?.first(type: .navigationStack))
        let navigation = try XCTUnwrap((stack.native as? UIKitElement)?.controller as? UIKitNavigationController)
        host.settle { navigation.view.window != nil && navigation.transitionCoordinator == nil }

        path.wrappedValue = [1, 2]
        host.settle { navigation.viewControllers.count == 3 }
        XCTAssertNotNil(navigation.transitionCoordinator, "two pages pushed in one move")
        host.settle { navigation.transitionCoordinator == nil }

        path.wrappedValue = [3, 2]
        host.settle { navigation.viewControllers.count == 3 && navigation.topViewController != nil }
        host.runtime.pump.turn()
        XCTAssertNil(navigation.transitionCoordinator, "a page under the top replaced: no move")

        path.wrappedValue = []
        host.settle { navigation.viewControllers.count == 1 }
        XCTAssertNotNil(navigation.transitionCoordinator, "two pages popped in one move back")
        host.settle { navigation.transitionCoordinator == nil }
    }

    /// The user's way back is not undone by a render while the page goes. The stack is told once the move ends, so a
    /// render meanwhile still describes the page going - and the stack shows it no more.
    @MainActor
    func testARenderWhileTheUserGoesBackLeavesThePageGone() throws {
        let path = State(wrappedValue: [1])
        let painted = State(wrappedValue: false)
        let host = UIKitRenderer.running {
            NavigationStack(path.projectedValue) {
                Text("Root")
            } destination: { level in
                Text("Level \(level)")
            }
            .barBackgroundColor(painted.wrappedValue ? .firebrick : .steelBlue)
        }
        defer { host.finish() }
        let stack = try XCTUnwrap(host.runtime.tree.root?.first(type: .navigationStack))
        let navigation = try XCTUnwrap((stack.native as? UIKitElement)?.controller as? UIKitNavigationController)
        host.settle { navigation.viewControllers.count == 2 && navigation.transitionCoordinator == nil }

        navigation.popViewController(animated: true)
        painted.wrappedValue = true
        host.runtime.pump.turn()
        XCTAssertEqual(navigation.viewControllers.count, 1, "the page the user took away stays away")

        host.settle { path.wrappedValue.isEmpty && navigation.transitionCoordinator == nil }
        XCTAssertEqual(path.wrappedValue, [], "the move ended: the path is shortened")
        XCTAssertEqual(navigation.viewControllers.count, 1)
    }

    /// A page with no bar over it stands clear of the window's own controls in its corner - an iPad's window - as
    /// well as of the screen's bars.
    @MainActor
    func testAPageWithNoBarStandsClearOfTheWindowsControls() throws {
        let host = UIKitRenderer.running { Text("Words at the top") }
        defer { host.finish() }
        let words = try XCTUnwrap(host.views(UIKitTextView.self).first)
        host.settle { words.window != nil && words.bounds.width > 0 }
        let window = try XCTUnwrap(words.window)
        let clear = window.edgeInsets(for: .safeArea(cornerAdaptation: .vertical))

        let corner = words.convert(CGPoint.zero, to: window)
        XCTAssertGreaterThanOrEqual(corner.y, clear.top, "below the window's controls")
    }

    /// A field in the title's place keeps its width while the user types into it: a control is not fitted to its
    /// words again at every render, which cut it and let the bar widen it again, letter by letter.
    @MainActor
    func testATitleFieldKeepsItsWidthWhileTheUserTypes() throws {
        let query = State(wrappedValue: "")
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Found \(query.wrappedValue)").titleView {
                    SearchField(query.projectedValue).placeholder("Search the list").id("query")
                }
            } destination: { _ in Text("Pushed") }
        }
        defer { host.finish() }
        let field = { (host.runtime.tree.root?.first(id: .manual("query"))?.native as? UIKitElement)?.view as? UITextField }
        host.settle { field()?.window != nil }
        let search = try XCTUnwrap(field())
        let width = search.bounds.width
        XCTAssertTrue(search.becomeFirstResponder())

        for letter in ["b", "e", "t"] {
            search.insertText(letter)
            host.runtime.pump.turn()
            search.window?.layoutIfNeeded()
            XCTAssertEqual(search.bounds.width, width, "after \(letter)")
        }
        XCTAssertEqual(query.wrappedValue, "bet")
    }

    /// The main menu is built again when an entry turns checked or is marked destructive, though its words stay:
    /// UIKit changes no built menu in place.
    @MainActor
    func testTheMenuBarIsBuiltAgainWhenAnEntryTurns() throws {
        let on = State(wrappedValue: false)
        let host = UIKitRenderer.running(reducesMotion: true) {
            Text("Document").menuBar { Menu("View") { MenuToggle("Grid", isOn: on.wrappedValue) }.id("view") }
        }
        defer { host.finish() }
        host.settle { !host.menuBar.isEmpty }
        let builds = host.menuBarBuildsForTesting

        on.wrappedValue = true
        host.settle { host.menuBarBuildsForTesting > builds }

        XCTAssertEqual(host.menuBarBuildsForTesting, builds + 1, "built again for the check")
    }

    /// The main menu is built again when an entry answers another element though it says the same: the page's Save
    /// standing in the place of the stack's carries the page's element in its identifier.
    @MainActor
    func testTheMenuBarIsBuiltAgainWhenAnEntryAnswersAnotherElement() throws {
        let saves = State(wrappedValue: false)
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Document").menuBar {
                    Menu("File") {
                        if saves.wrappedValue { MenuItem("Save").id("save") }
                    }
                    .id("file")
                }
            } destination: { _ in Text("Pushed") }
            .menuBar { Menu("File") { MenuItem("Save").id("save") }.id("file") }
        }
        defer { host.finish() }
        host.settle { !host.menuBar.isEmpty }
        let words = UIKitMenus.said(host.menuBar)
        let identified = UIKitMenus.said(host.menuBar, identified: true)

        saves.wrappedValue = true
        host.settle { UIKitMenus.said(host.menuBar, identified: true) != identified }
        XCTAssertEqual(UIKitMenus.said(host.menuBar), words, "the same words")
        XCTAssertNotEqual(UIKitMenus.said(host.menuBar, identified: true), identified, "another element's")
    }

    /// An entry stating a shortcut stands in the main menu as a key command, which UIKit shows the shortcut of and
    /// the window's root chooses the entry by, the root offering no command of its own for those keys; the main menu
    /// is built again when the shortcut changes.
    @MainActor
    func testAnEntrysShortcutStandsInTheMenuBarAsAKeyCommand() throws {
        let shifted = State(wrappedValue: false)
        let heard = Received<Int>()
        let host = UIKitRenderer.running(reducesMotion: true) {
            Text("Document").menuBar {
                Menu("File") {
                    MenuItem("Save").keyboardShortcut("s", modifiers: shifted.wrappedValue ? [.primary, .shift] : .primary)
                        .onClicked { heard.values.append(1) }.id("save")
                }
                .id("file")
            }
        }
        defer { host.finish() }
        host.settle { !host.menuBar.isEmpty }
        func command() -> UIKeyCommand? { host.menuBar.first?.children.first as? UIKeyCommand }
        XCTAssertEqual(command().flatMap(UIKitKeys.shortcut(of:)), KeyboardShortcut("s"))
        let identified = UIKitMenus.said(host.menuBar, identified: true)

        shifted.wrappedValue = true
        host.settle { UIKitMenus.said(host.menuBar, identified: true) != identified }
        XCTAssertNotEqual(UIKitMenus.said(host.menuBar, identified: true), identified, "built again")
        XCTAssertEqual(command().flatMap(UIKitKeys.shortcut(of:)), KeyboardShortcut("s", modifiers: [.primary, .shift]))

        let root = try XCTUnwrap(host.userWindow?.rootViewController as? UIKitRootViewController)
        XCTAssertFalse(
            root.keyCommands?.contains { UIKitKeys.shortcut(of: $0) == KeyboardShortcut("s", modifiers: [.primary, .shift]) }
                ?? false,
            "the main menu's alone: UIKit shows no shortcut on a command another responder's overrides")
        root.chooseMenuEntry(try XCTUnwrap(command()))
        host.settle { !heard.values.isEmpty }
        XCTAssertEqual(heard.values, [1], "the entry chosen")
    }

    /// The groups a page declares stand on its navigation item as the host layer composes them: each a
    /// `UIBarButtonItemGroup` of its own - a background of its own - in reading order, a leading group beside the
    /// way back.
    @MainActor
    func testTheBarsGroupsStandAsThePageDeclaresThem() throws {
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root")
                    .toolbar {
                        ToolbarGroup {
                            ToolbarButton("Save").accessibilityIdentifier("save")
                            ToolbarButton("Add").accessibilityIdentifier("add")
                        }
                        ToolbarButton("Filter").accessibilityIdentifier("filter").placement(at: .start)
                        ToolbarButton("Home").accessibilityIdentifier("home")
                    }
            } destination: { _ in Text("Pushed") }
        }
        defer { host.finish() }
        let item = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement)?.controller?.navigationItem }
        let said = { (groups: [UIBarButtonItemGroup]) in groups.map { $0.barButtonItems.map { $0.accessibilityIdentifier ?? "" } } }
        host.settle { item().map { !$0.trailingItemGroups.isEmpty } ?? false }

        let bar = try XCTUnwrap(item())
        XCTAssertEqual(said(bar.trailingItemGroups), [["save", "add"], ["home"]])
        XCTAssertEqual(said(bar.leadingItemGroups), [["filter"]])
        XCTAssertTrue(bar.leftItemsSupplementBackButton, "the leading group beside the way back")
    }

    /// The overflow's button, a picture on the bar, is named More: UIKit's own menu of the items a narrow bar has no
    /// room for, and VoiceOver, say its title.
    @MainActor
    func testTheOverflowIsNamedMore() throws {
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root").toolbar { ToolbarButton("Clear").placement(at: .overflow) }
            } destination: { _ in Text("Pushed") }
        }
        defer { host.finish() }
        let item = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement)?.controller?.navigationItem }
        host.settle { item().map { !$0.trailingItemGroups.isEmpty } ?? false }
        let more = try XCTUnwrap(item()?.trailingItemGroups.flatMap(\.barButtonItems).first { $0.menu != nil })

        XCTAssertEqual(more.title, CoreLink().chromeWords.more)
    }

    /// A bar's buttons - an action, and one holding a menu - let go of their elements as the bar drops them: the action
    /// UIKit was handed, which the element keeps, holds neither the element nor its menu's entries.
    @MainActor
    func testABarsButtonsLeaveNothingAlive() throws {
        let shown = State(wrappedValue: true)
        weak var action: MountedElement?
        weak var withMenu: MountedElement?
        weak var actionNative: UIKitElement?
        weak var withMenuNative: UIKitElement?
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root").toolbar {
                    if shown.wrappedValue {
                        ToolbarButton("Add")
                        ToolbarButton("Save").onClicked {}.menu(.split) { MenuItem("Save as") }
                    }
                }
            } destination: { _ in Text("Pushed") }
        }
        defer { host.finish() }
        let item = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement)?.controller?.navigationItem }
        host.settle { item().map { $0.trailingItemGroups.flatMap(\.barButtonItems).count == 2 } ?? false }
        autoreleasepool {
            let buttons = host.runtime.tree.root.map { Self.all(.toolbarButton, in: $0) } ?? []
            XCTAssertEqual(buttons.count, 2)
            (action, withMenu) = (buttons.first, buttons.last)
            (actionNative, withMenuNative) = (action?.native as? UIKitElement, withMenu?.native as? UIKitElement)

            shown.wrappedValue = false
            host.settle { item()?.trailingItemGroups.flatMap(\.barButtonItems).isEmpty ?? false }
        }
        let settled = Date(timeIntervalSinceNow: 0.3)
        while Date() < settled { RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02)) }

        XCTAssertNil(action, "the action's element")
        XCTAssertNil(withMenu, "the element of the button holding a menu")
        XCTAssertNil(actionNative, "the action's UIKit element")
        XCTAssertNil(withMenuNative, "the UIKit element of the button holding a menu")
    }

    /// On a painted bar an action wears the bar's words' color, and one that destroys something stays red.
    @MainActor
    func testADestructiveActionStaysRedOnAPaintedBar() throws {
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root").toolbar {
                    ToolbarButton("Save").accessibilityIdentifier("save")
                    ToolbarButton("Delete").role(.destructive).accessibilityIdentifier("delete")
                }
            } destination: { _ in Text("Pushed") }
            .barBackgroundColor(Color(red: 0, green: 0, blue: 128))
        }
        defer { host.finish() }
        let item = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement)?.controller?.navigationItem }
        host.settle { item().map { !$0.trailingItemGroups.isEmpty } ?? false }
        let items = try XCTUnwrap(item()).trailingItemGroups.flatMap(\.barButtonItems)
        let tint = { (id: String) in items.first { $0.accessibilityIdentifier == id }?.tintColor }

        XCTAssertEqual(tint("delete"), .systemRed, "the destructive one red")
        var white: CGFloat = -1
        XCTAssertTrue(tint("save")?.getWhite(&white, alpha: nil) == true)
        XCTAssertEqual(white, 1, accuracy: 0.01, "the other in the bar's words, light on navy")
    }

    /// A bar whose actions say what they said keeps its buttons as the page's title or the bar's color moves - a
    /// letter typed in a field on the bar, a frame of a color traveling - recolored, never made again.
    @MainActor
    func testABarKeepsItsButtonsWhileItsActionsSayTheSame() throws {
        let title = State(wrappedValue: "One")
        let dark = State(wrappedValue: true)
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root").title(title.wrappedValue).toolbar {
                    ToolbarButton("Save").accessibilityIdentifier("save")
                }
            } destination: { _ in Text("Pushed") }
            .barBackgroundColor(dark.wrappedValue ? Color(red: 0, green: 0, blue: 128) : Color(red: 255, green: 230, blue: 0))
        }
        defer { host.finish() }
        let item = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement)?.controller?.navigationItem }
        host.settle { item().map { !$0.trailingItemGroups.isEmpty } ?? false }
        let save = try XCTUnwrap(item()?.trailingItemGroups.first?.barButtonItems.first)

        title.wrappedValue = "Two"
        host.settle { item()?.title == "Two" }
        XCTAssertTrue(item()?.trailingItemGroups.first?.barButtonItems.first === save, "kept as the title moved")

        dark.wrappedValue = false
        var white: CGFloat = 1
        host.settle { save.tintColor?.getWhite(&white, alpha: nil) == true && white < 0.5 }
        XCTAssertTrue(item()?.trailingItemGroups.first?.barButtonItems.first === save, "kept as the color moved")
        XCTAssertLessThan(white, 0.5, "and recolored, dark on yellow")
    }

    /// Words on a bar the tree paints stand light on a dark bar and dark on a light one, where the tree writes no
    /// color for them (`BandWords`).
    @MainActor
    func testWordsOnAPaintedBarFollowHowDarkItIs() throws {
        let dark = State(wrappedValue: true)
        let (navy, yellow) = (Color(red: 0, green: 0, blue: 128), Color(red: 255, green: 230, blue: 0))
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                TitledPage(title: "Root")
            } destination: { _ in Text("Pushed") }
                .barBackgroundColor(dark.wrappedValue ? navy : yellow)
        }
        defer { host.finish() }
        let page = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement)?.controller }
        let words = { () -> CGFloat? in
            let color = page()?.navigationItem.standardAppearance?.titleTextAttributes[.foregroundColor] as? UIColor
            var white: CGFloat = -1
            return color?.getWhite(&white, alpha: nil) == true ? white : nil
        }
        host.settle { words() != nil }
        XCTAssertEqual(words() ?? -1, 1, accuracy: 0.01, "light on navy")

        dark.wrappedValue = false
        host.settle { (words() ?? 1) < 0.01 }
        XCTAssertEqual(words() ?? -1, 0, accuracy: 0.01, "dark on yellow")
    }

    /// A tab the user chooses from UIKit's More list - a phone offers six and more so - is the tab chosen: the
    /// selection follows it.
    @MainActor
    func testATabChosenFromTheMoreListIsChosen() throws {
        let tab = State(wrappedValue: 0)
        let host = UIKitRenderer.running(reducesMotion: true) {
            TabView(0..<7, selection: tab.projectedValue) { number in Text("Tab \(number)").title("Tab \(number)") }
        }
        defer { host.finish() }
        let element = host.runtime.tree.root.flatMap { Self.first(.tabView, in: $0) }
        let tabs = try XCTUnwrap((element?.native as? UIKitElement)?.controller as? UIKitTabBarController)
        guard tabs.traitCollection.horizontalSizeClass == .compact else { throw XCTSkip("an iPad shows every tab") }
        let seventh = try XCTUnwrap(tabs.viewControllers?.last)

        // As the More list does when the user picks a tab in it.
        tabs.selectedViewController = tabs.moreNavigationController
        tabs.moreNavigationController.pushViewController(seventh, animated: false)
        host.settle { tab.wrappedValue == 6 }

        XCTAssertEqual(tab.wrappedValue, 6)
    }

    /// A tab bar wears the words' color of the bar on its path as it changes - written on the stack it stands in, so
    /// the tabbed view itself changes nothing - in every layout it lays its tabs in.
    @MainActor
    func testATabBarFollowsTheBarsWordsOnItsPath() throws {
        let white = State(wrappedValue: false)
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                TabView([0, 1]) { Text("\($0)").title("Tab \($0)") }
            } destination: { _ in Text("Pushed") }
                .barForegroundColor(white.wrappedValue ? .white : .black)
        }
        defer { host.finish() }
        let tabs = { (host.runtime.tree.root.flatMap { Self.first(.tabView, in: $0) }?.native as? UIKitElement)?.controller }
        let words = { () -> CGFloat? in
            let bar = (tabs() as? UITabBarController)?.tabBar.standardAppearance
            let color = bar?.stackedLayoutAppearance.selected.titleTextAttributes[.foregroundColor] as? UIColor
            var shade: CGFloat = -1
            return color?.getWhite(&shade, alpha: nil) == true ? shade : nil
        }
        host.settle { words() != nil }
        XCTAssertEqual(words() ?? -1, 0, accuracy: 0.01, "black")

        white.wrappedValue = true
        host.settle { (words() ?? 0) > 0.99 }
        XCTAssertEqual(words() ?? -1, 1, accuracy: 0.01, "white, the stack's words changed")

        // The same in every layout of the bar: a phone turned and an iPad lay their tabs inline.
        let bar = try XCTUnwrap((tabs() as? UITabBarController)?.tabBar.standardAppearance)
        for layout in [bar.inlineLayoutAppearance, bar.compactInlineLayoutAppearance] {
            XCTAssertEqual(layout.selected.iconColor, bar.stackedLayoutAppearance.selected.iconColor)
            XCTAssertEqual(
                layout.selected.titleTextAttributes[.foregroundColor] as? UIColor,
                bar.stackedLayoutAppearance.selected.titleTextAttributes[.foregroundColor] as? UIColor)
        }
    }

    /// A clear bar is UIKit's transparent bar: nothing under it, and no line between it and the page.
    @MainActor
    func testAClearBarDrawsNoLineUnderIt() throws {
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                TitledPage(title: "Root")
            } destination: { _ in Text("Pushed") }
                .barBackgroundColor(.transparent)
        }
        defer { host.finish() }
        let page = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement)?.controller }
        host.settle { page()?.navigationItem.standardAppearance != nil }
        let appearance = try XCTUnwrap(page()?.navigationItem.standardAppearance)

        var alpha: CGFloat = 0
        appearance.shadowColor?.getWhite(nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0, "no line under the bar")
        appearance.backgroundColor?.getWhite(nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0, "nothing under it")
    }

    /// A page's content stands clear of the bars and the notch, but where it lets itself under them it reaches the
    /// screen's edge; the page's background stands behind the bars either way.
    @MainActor
    func testAPagesContentReachesUnderTheBarsWhereItSaysSo() throws {
        let under = State(wrappedValue: false)
        let host = UIKitRenderer.running {
            ZStack {}.ignoresSafeArea(under.wrappedValue ? .all : .none)
        }
        defer { host.finish() }
        let page = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement) }
        let controller = try XCTUnwrap(page()?.controller)
        host.settle { controller.view.safeAreaInsets.top > 0 }
        let top = controller.view.safeAreaInsets.top
        XCTAssertGreaterThan(top, 0, "the phone has a notch")
        XCTAssertEqual(try XCTUnwrap(page()?.view).frame.minY, top, "clear of the notch")

        under.wrappedValue = true
        host.settle { page()?.view?.frame.minY == 0 }
        XCTAssertEqual(try XCTUnwrap(page()?.view).frame.minY, 0, "under it")
    }

    /// A stack's bar is part of the safe area of the page under it: the page's content stands clear of it, and where
    /// it lets itself under the bars it reaches the screen's top edge, under the bar.
    @MainActor
    func testAPagesContentReachesUnderAStacksBarWhereItSaysSo() throws {
        let under = State(wrappedValue: false)
        let host = UIKitRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                ZStack {}.ignoresSafeArea(under.wrappedValue ? .all : .none).title("Under the bar")
            } destination: { _ in Text("Next") }
        }
        defer { host.finish() }
        let page = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement) }
        let controller = try XCTUnwrap(page()?.controller)
        let bar = try XCTUnwrap(controller.navigationController?.navigationBar)
        host.settle { bar.window != nil && (page()?.view?.frame.minY ?? 0) > 0 }
        let below = Double(controller.view.convert(bar.bounds, from: bar).maxY)
        let standing = Double(try XCTUnwrap(page()?.view?.frame.minY))
        XCTAssertEqual(standing, below, accuracy: 0.5, "clear of the bar")

        under.wrappedValue = true
        host.settle { page()?.view?.frame.minY == 0 }
        XCTAssertEqual(try XCTUnwrap(page()?.view).frame.minY, 0, "under it")
    }

    /// A page's scroller let under a stack's bar scrolls under it and keeps the bar's depth clear at its start, so
    /// its first row stands clear of the bar at the offset the tree calls nothing.
    @MainActor
    func testAPagesScrollerUnderTheBarKeepsItsFirstRowClear() throws {
        let offset = State(wrappedValue: Point(0, 0))
        let host = UIKitRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Grid { ScrollView { Text("rows").height(2000) }.scrollOffset(offset.projectedValue) }
                    .ignoresSafeArea(.all)
                    .title("Rows")
            } destination: { _ in Text("Next") }
        }
        defer { host.finish() }
        let scroller = { host.views(UIKitScrollView.self).first?.scroller }
        host.settle { (scroller()?.contentInset.top ?? 0) > 0 }
        let top = Double(try XCTUnwrap(scroller()).contentInset.top)
        XCTAssertGreaterThan(top, 0, "the bar's depth kept clear")
        let start = Double(try XCTUnwrap(scroller()?.contentOffset.y))
        XCTAssertEqual(start, -top, accuracy: 0.5, "its first row clear of the bar")
        XCTAssertEqual(offset.wrappedValue, Point(0, 0), "where the tree calls nothing")

        offset.wrappedValue = Point(0, 100)
        host.settle { abs(Double(scroller()?.contentOffset.y ?? 0) - (100 - top)) < 0.5 }
        let moved = Double(try XCTUnwrap(scroller()?.contentOffset.y))
        XCTAssertEqual(moved, 100 - top, accuracy: 0.5, "counted from its first row")
    }

    /// A page's scroller let under the strip at its bottom scrolls under the home indicator and keeps the strip
    /// clear at its end, so its last row scrolls out from under it; one standing clear of the strip keeps nothing.
    @MainActor
    func testAPagesScrollerUnderTheHomeIndicatorKeepsItClearAtItsEnd() throws {
        let under = State(wrappedValue: true)
        let host = UIKitRenderer.running {
            Grid { ScrollView { Text("rows") } }
                .ignoresSafeArea(under.wrappedValue ? .bottom : .none)
        }
        defer { host.finish() }
        let scroller = { host.views(UIKitScrollView.self).first?.scroller }
        let page = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement) }
        let controller = try XCTUnwrap(page()?.controller)
        host.settle { controller.view.safeAreaInsets.bottom > 0 && (scroller()?.contentInset.bottom ?? 0) > 0 }
        let strip = controller.view.safeAreaInsets.bottom
        XCTAssertGreaterThan(strip, 0, "the phone has a home indicator")
        XCTAssertEqual(try XCTUnwrap(scroller()).contentInset.bottom, strip, "the strip kept clear at its end")
        XCTAssertEqual(try XCTUnwrap(scroller()).contentInset.top, 0, "its start as it is")

        under.wrappedValue = false
        host.settle { scroller()?.contentInset.bottom == 0 }
        XCTAssertEqual(try XCTUnwrap(scroller()).contentInset.bottom, 0, "clear of the strip, nothing to keep")
    }

    /// A page's background stands behind the whole screen, the strip under the home indicator and the bars
    /// included - never the system's white there.
    @MainActor
    func testAPagesBackgroundStandsBehindTheWholeScreen() throws {
        let host = UIKitRenderer.running { PaintedPage() }
        defer { host.finish() }
        let page = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement) }
        let controller = try XCTUnwrap(page()?.controller)
        host.settle { controller.view.backgroundColor != .systemBackground }
        var (red, green, blue): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
        controller.view.backgroundColor?.getRed(&red, green: &green, blue: &blue, alpha: nil)
        XCTAssertEqual([red, green, blue].map { Int(($0 * 255).rounded()) }, [247, 245, 252])
    }

    /// A page that paints no background of its own shows its window's: a UIKit window shows only through its
    /// pages, each controller's view opaque.
    @MainActor
    func testAPageWithNoBackgroundShowsItsWindows() throws {
        let host = UIKitRenderer.running { WindowPaintedPage() }
        defer { host.finish() }
        let page = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement) }
        let controller = try XCTUnwrap(page()?.controller)
        host.settle { controller.view.backgroundColor != .systemBackground }
        var (red, green, blue): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
        controller.view.backgroundColor?.getRed(&red, green: &green, blue: &blue, alpha: nil)
        XCTAssertEqual([red, green, blue].map { Int(($0 * 255).rounded()) }, [81, 43, 212], "the window's color")
    }

    /// The first tabbed view in `element`'s tree.
    @MainActor
    private static func tabView(in element: MountedElement) -> MountedElement? {
        first(.tabView, in: element)
    }

    /// The first element of `type` in `element`'s tree.
    @MainActor
    private static func first(_ type: NodeType, in element: MountedElement) -> MountedElement? {
        element.type == type ? element : element.children.lazy.compactMap { first(type, in: $0) }.first
    }

    /// Every element of `type` in `element`'s tree, in order.
    @MainActor
    private static func all(_ type: NodeType, in element: MountedElement) -> [MountedElement] {
        (element.type == type ? [element] : []) + element.children.flatMap { all(type, in: $0) }
    }
}

/// A page that names itself.
private struct TitledPage: View {
    let title: String

    var body: some View {
        Text(title).title(title)
    }
}

/// A page whose background the page itself says, as the Gallery's pages do.
private struct PaintedPage: View {
    var body: some View {
        Text("Painted").pageBackground(Color(hex: 0xF7F5FC))
    }
}

private struct WindowPaintedPage: View {
    @Environment(\.window) private var window

    var body: some View {
        Text("Plain").onCreated { window.background = .color(Color(hex: 0x512BD4)) }
    }
}
