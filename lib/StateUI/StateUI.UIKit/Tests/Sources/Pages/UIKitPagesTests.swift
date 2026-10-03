// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// What pages and their arrangements say on UIKit's bars and the window's scene.
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

    /// The groups a page's path declares stand on its navigation item as the host layer composes them: each a
    /// `UIBarButtonItemGroup` of its own - a background of its own - the page's nearer the title and the stack's at
    /// the edge, a leading group beside the way back.
    @MainActor
    func testTheBarsGroupsStandAsThePathComposesThem() throws {
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root")
                    .toolbar {
                        ToolbarItem("Save").accessibilityIdentifier("save")
                        ToolbarItem("Add").accessibilityIdentifier("add")
                    }
                    .toolbar(.leading) { ToolbarItem("Filter").accessibilityIdentifier("filter") }
            } destination: { _ in Text("Pushed") }
            .toolbar { ToolbarItem("Home").accessibilityIdentifier("home") }
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

    /// Words on a bar the tree paints stand light on a dark bar and dark on a light one, where the tree writes no
    /// colour for them (`BandWords`).
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

    /// A page's content stands clear of the bars and the notch, but where it lets itself under them it reaches the
    /// screen's edge; the page's background stands behind the bars either way.
    @MainActor
    func testAPagesContentReachesUnderTheBarsWhereItSaysSo() throws {
        let under = State(wrappedValue: false)
        let host = UIKitRenderer.running {
            ZStack {}.avoidsSafeArea(under.wrappedValue ? .none : .container)
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
        Text("Painted").pageBackground(Color("#F7F5FC"))
    }
}
