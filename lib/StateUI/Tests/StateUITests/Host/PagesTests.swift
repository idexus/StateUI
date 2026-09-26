// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// What an arrangement of pages shows, the phases its pages hear, and the chrome and the way back a window offers,
/// the same on every host.
@MainActor
final class PagesTests: XCTestCase {
    private func node(
        _ id: String, _ type: NodeType, _ properties: [Prop: HostValue] = [:], events: [Event: Int32] = [:],
        children: [HostPatch] = []
    ) -> HostPatch {
        var patch = HostPatch(id: .manual(id), type: type)
        patch.properties = properties
        patch.events = .replace(events)
        patch.children = .arranged(children)
        return patch
    }

    /// A runtime holding `root`, whose phases are written down in the order told.
    private func runtime(_ root: HostPatch, told: @escaping (Int32) -> Void) -> HostRuntime {
        let runtime = HostRuntime.still()
        runtime.tree.apply(root, complete: true)
        runtime.tree.tellPhase = told
        return runtime
    }

    private func stackWindow(_ pages: [HostPatch]) -> HostPatch {
        node("window", .window, events: [.created: 1], children: [node("stack", .navigationStack, children: pages)])
    }

    private let first = [Event.appearing: Int32(2), .navigatedTo: 3]
    private let second = [Event.appearing: Int32(4), .navigatedTo: 5, .navigatingFrom: 6, .disappearing: 7,
                          .navigatedFrom: 8]

    /// A window's visible page hears it is shown, navigated to as its stack's top, and then the window that it was
    /// made - before the host shows it.
    func testAWindowTellsItsPageThenThatItWasMade() throws {
        var told: [Int32] = []
        let runtime = runtime(stackWindow([node("a", .page, events: first), node("b", .page, events: second)])) {
            told.append($0)
        }

        _ = WindowPresentation().show(try XCTUnwrap(runtime.tree.root))

        XCTAssertEqual(told, [4, 5, 1])
    }

    /// A pop tells the page leaving everything it hears on a move before the page arriving hears anything.
    func testAPopTellsTheLeavingPageBeforeTheArrivingOne() throws {
        var told: [Int32] = []
        let runtime = runtime(stackWindow([node("a", .page, events: first), node("b", .page, events: second)])) {
            told.append($0)
        }
        _ = WindowPresentation().show(try XCTUnwrap(runtime.tree.root))
        told = []

        runtime.tree.apply(stackWindow([node("a", .page, events: first)]), complete: false)

        XCTAssertEqual(told, [6, 7, 8, 2, 3])
    }

    /// A tabbed view's tabs stand in the window's row down its stacks and split view details, and nowhere else.
    func testTabsStandInTheWindowDownItsStacksAndDetails() throws {
        let tabs = { (id: String) in self.node(id, .tabbedView, children: [self.node("\(id).page", .page)]) }
        let runtime = runtime(node("window", .window, children: [
            node("split", .splitView, children: [
                tabs("sidebar"),
                node("stack", .navigationStack, children: [node("detail", .tabbedView, children: [tabs("inner")])]),
            ]),
            node("sheets", .modalStack, children: [tabs("sheet")]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let stands = { (id: String) in root.first(id: .manual(id))?.tabsStandInWindow }

        XCTAssertEqual(stands("detail"), true)
        XCTAssertEqual(stands("sidebar"), false, "a sidebar keeps its own row")
        XCTAssertEqual(stands("inner"), false, "a tab of another keeps its own row")
        XCTAssertEqual(stands("sheet"), false, "a sheet keeps its own row")
    }

    /// A tab the tree asks for anew is chosen; the user's choice stands where it is another tab there is.
    func testATabChoiceFollowsTheTreeAndTheUser() {
        var choice = TabChoice()
        XCTAssertEqual(choice.shown, 0)
        XCTAssertFalse(choice.request(nil))
        XCTAssertTrue(choice.request(2))
        XCTAssertFalse(choice.request(2), "asked again, nothing changes")
        XCTAssertEqual(choice.choose(1, of: 3), 2, "the tab shown before")
        XCTAssertNil(choice.choose(1, of: 3), "the tab shown already")
        XCTAssertNil(choice.choose(5, of: 3), "no such tab")
        XCTAssertEqual(choice.shown, 1)
    }

    /// Only the first room wider than nothing decides: a room at least the breakpoint shows a hidden sidebar.
    func testASidebarShowsOnTheFirstWideRoomOnly() {
        var adaptation = SidebarAdaptation()
        XCTAssertFalse(adaptation.room(0, breakpoint: 700, shown: false), "no room yet")
        XCTAssertTrue(adaptation.room(900, breakpoint: 700, shown: false))
        XCTAssertFalse(adaptation.room(900, breakpoint: 700, shown: false), "decided once")

        var narrow = SidebarAdaptation()
        XCTAssertFalse(narrow.room(500, breakpoint: 700, shown: false))
    }

    /// The chrome takes the visible page's actions by priority then order, the overflow apart, the way back's words
    /// from the page beneath, the title bar's content over the page's title view, and the stack's colour first.
    func testTheChromeIsComposedFromWhatTheWindowShows() throws {
        let item = { (id: String, priority: Double, overflow: Bool) in
            self.node(id, .toolbarItem, [
                .priority: .number(priority),
                .placement: .enumeration(overflow ? ToolbarItemPlacement.overflow.rawValue : 0),
            ])
        }
        let runtime = runtime(node("window", .window, children: [
            node("bar", .titleBar, [.background: .string("bar")], children: [
                node("slot", .content, children: [node("search", .label)]),
            ]),
            node("stack", .navigationStack, [.barBackgroundColor: .string("stack")], children: [
                node("home", .page, [.backButtonTitle: .string("Home")]),
                node("detail", .page, [.title: .string("Detail")], children: [
                    node("items", .toolbarItems, children: [
                        item("late", 2, false), item("more", 0, true), item("first", 1, false), item("next", 1, false),
                    ]),
                    node("view", .titleView, children: [node("words", .label)]),
                ]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)

        let chrome = WindowChrome(window: root, arrangement: root.first(id: .manual("stack")))
        XCTAssertEqual(chrome.title, "Detail")
        XCTAssertEqual(chrome.back?.title, "Home")
        XCTAssertEqual(chrome.primaryActions.map(\.id), [.manual("first"), .manual("next"), .manual("late")])
        XCTAssertEqual(chrome.overflowActions.map(\.id), [.manual("more")])
        XCTAssertEqual(chrome.center?.id, .manual("search"), "the title bar's content over the page's title view")
        XCTAssertEqual(chrome.background, .string("stack"))
        XCTAssertNil(chrome.sidebarToggle)
    }

    /// A menu walks its items, separators and submenus in order, each with its caption and whether it can be chosen;
    /// a bar holds only its menus.
    func testAMenuIsWalkedInOrder() throws {
        let runtime = runtime(node("bar", .menuBar, children: [
            node("file", .menu, [.text: .string("File")], children: [
                node("open", .menuItem, [.text: .string("Open")]),
                node("line", .menuSeparator),
                node("recent", .menu, [.text: .string("Recent")], children: [
                    node("one", .menuItem, [.text: .string("One"), .isEnabled: .bool(false)]),
                ]),
            ]),
            node("stray", .menuItem),
        ])) { _ in }

        let menus = MenuEntry.menus(of: try XCTUnwrap(runtime.tree.root))
        XCTAssertEqual(menus.map(\.title), ["File"], "the bar holds only its menus")
        let file = try XCTUnwrap(menus.first).entries
        XCTAssertEqual(file.map(\.kind), [.item, .separator, .submenu])
        XCTAssertEqual(file.map(\.title), ["Open", "", "Recent"])
        XCTAssertEqual(file.last?.entries.map(\.isEnabled), [false])
    }

    /// A page's slots furnish its chrome and stand in none of its room; another element places every child.
    func testAPagePlacesAllButItsSlots() throws {
        let runtime = runtime(node("page", .page, children: [
            node("items", .toolbarItems), node("words", .label), node("view", .titleView),
        ])) { _ in }

        XCTAssertEqual(try XCTUnwrap(runtime.tree.root).arrangedChildren.map(\.id), [.manual("words")])
    }

    /// Back in a window takes the top sheet's own stack, else the top sheet, else the arrangement's stack.
    func testTheWayBackTakesTheTopSheetFirst() throws {
        let twoPages = { (id: String) in
            self.node(id, .navigationStack, children: [self.node("\(id).a", .page), self.node("\(id).b", .page)])
        }
        func wayBack(_ sheets: [HostPatch]) throws -> WayBack? {
            let runtime = runtime(node("window", .window, children: [twoPages("main"), node("modal", .modalStack, children: sheets)])) {
                _ in
            }
            let presentation = WindowPresentation()
            _ = presentation.show(try XCTUnwrap(runtime.tree.root))
            return presentation.wayBack
        }

        guard case .pop(let stack) = try wayBack([twoPages("sheet")]) else { return XCTFail("the sheet's stack") }
        XCTAssertEqual(stack.id, .manual("sheet"))
        guard case .dismissSheet(let remaining) = try wayBack([node("one", .page), node("two", .page)]) else {
            return XCTFail("the top sheet")
        }
        XCTAssertEqual(remaining, 1)
        guard case .pop(let main) = try wayBack([]) else { return XCTFail("the arrangement's stack") }
        XCTAssertEqual(main.id, .manual("main"))
    }
}
