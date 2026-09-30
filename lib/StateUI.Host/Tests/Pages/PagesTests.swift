// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
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

        _ = WindowPresentation().show(try XCTUnwrap(runtime.tree.root), in: runtime.lifecycle)

        XCTAssertEqual(told, [4, 5, 1])
    }

    /// A pop tells the page leaving everything it hears on a move before the page arriving hears anything.
    func testAPopTellsTheLeavingPageBeforeTheArrivingOne() throws {
        var told: [Int32] = []
        let runtime = runtime(stackWindow([node("a", .page, events: first), node("b", .page, events: second)])) {
            told.append($0)
        }
        _ = WindowPresentation().show(try XCTUnwrap(runtime.tree.root), in: runtime.lifecycle)
        told = []

        runtime.tree.apply(stackWindow([node("a", .page, events: first)]), complete: false)

        XCTAssertEqual(told, [6, 7, 8, 2, 3])
    }

    /// A page made anew where one stood - another view in the stack's place - hears it is shown, as a page pushed
    /// there does.
    func testAPageMadeAnewInItsPlaceIsShown() throws {
        var told: [Int32] = []
        let runtime = runtime(stackWindow([node("a", .page, events: first)])) { told.append($0) }
        _ = WindowPresentation().show(try XCTUnwrap(runtime.tree.root), in: runtime.lifecycle)
        told = []

        var anew = node("a", .page, events: [.appearing: 9, .navigatedTo: 10])
        anew.replace = true
        runtime.tree.apply(stackWindow([anew]), complete: false)

        XCTAssertEqual(told, [9, 10])
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

    /// A stack shows its bar over a page that keeps one, and over tabs only where the chosen tab stands in no stack of
    /// its own, whose bar is the one.
    func testAStacksBarShowsOnlyWhereNoStackBelowHasOne() throws {
        let hidden = [Prop.hasNavigationBar: HostValue.bool(false)]
        let runtime = runtime(node("window", .window, children: [node("stack", .navigationStack, children: [
            node("page", .page),
            node("bare", .page, hidden),
            node("pages", .tabbedView, children: [node("tab", .page)]),
            node("stacks", .tabbedView, children: [node("inner", .navigationStack, children: [node("top", .page)])]),
        ])])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let shows = { (id: String) in root.first(id: .manual(id))?.showsTheStacksBar }

        XCTAssertEqual(shows("page"), true)
        XCTAssertEqual(shows("bare"), false, "a page hiding its bar")
        XCTAssertEqual(shows("pages"), true, "tabs of pages wear the bar of the stack they stand on")
        XCTAssertEqual(shows("stacks"), false, "a tab that is a stack has a bar of its own")
    }

    /// Where a tabbed view's tabs stand is already right as it is applied, while the tree that holds it is made.
    func testTabsStandRightWhileTheirTreeIsMade() {
        var read: [String: Bool] = [:]
        let runtime = HostRuntime(
            clock: StillClock(), reducesMotion: { false },
            makeNative: { TabsReading($0) { read[$0] = $1 } }, log: { _ in })
        let tabs = { (id: String) in self.node(id, .tabbedView, children: [self.node("\(id).page", .page)]) }

        runtime.tree.apply(
            node("window", .window, children: [node("split", .splitView, children: [tabs("sidebar"), tabs("detail")])]),
            complete: true)

        XCTAssertEqual(read, ["sidebar": false, "detail": true])
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

    /// The tab shown among the tabs there are: the chosen one while it is there, else the last - one answer for the
    /// view and its row; none among no tabs.
    func testTheTabShownIsOneOfTheTabsThereAre() {
        var choice = TabChoice()
        XCTAssertEqual(choice.shown(among: 3), 0)
        _ = choice.request(2)
        XCTAssertEqual(choice.shown(among: 3), 2)
        XCTAssertEqual(choice.shown(among: 2), 1, "the chosen tab gone, the last there is")
        XCTAssertNil(choice.shown(among: 0))
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

    /// An action's words stand on the bar beside its picture only where it says so, and always where it has none.
    func testAnActionShowsItsWordsBesideItsPictureWhereItSaysSo() throws {
        let runtime = runtime(node("page", .page, children: [
            node("items", .toolbarItems, children: [
                node("words", .toolbarItem, [.text: .string("Words")]),
                node("picture", .toolbarItem, [.text: .string("Picture"), .icon: .string("add")]),
                node("both", .toolbarItem, [.text: .string("Both"), .icon: .string("add"), .showsText: .bool(true)]),
                node("hidden", .toolbarItem, [.text: .string("Hidden"), .showsText: .bool(false)]),
            ]),
        ])) { _ in }
        let page = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(page.chromeActions.primary.map(\.showsActionWords), [true, false, true, true])
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

    /// An authored title bar says its own title, the line under it and its picture beside the page's title - where
    /// it says any of them; one saying none says nothing, an empty picture none.
    func testTheTitleBarSaysItsOwnTitleArea() throws {
        let runtime = runtime(node("window", .window, children: [
            node("bar", .titleBar, [.title: .string("StateUI"), .subtitle: .string("Fundamentals"), .icon: .string("")]),
            node("page", .page, [.title: .string("Buttons")]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let chrome = WindowChrome(window: root, arrangement: root.first(id: .manual("page")))

        XCTAssertEqual(chrome.title, "Buttons", "the page still names the window")
        XCTAssertEqual(chrome.titleArea, WindowChrome.TitleArea(title: "StateUI", subtitle: "Fundamentals", icon: nil))

        let bare = self.runtime(node("window", .window, children: [
            node("bar", .titleBar, [.background: .string("bar")]), node("page", .page),
        ])) { _ in }
        let bareRoot = try XCTUnwrap(bare.tree.root)
        XCTAssertNil(WindowChrome(window: bareRoot, arrangement: bareRoot.first(id: .manual("page"))).titleArea)
    }

    /// Tabs pushed onto a stack keep the title of the page beneath them; tabs with nothing beneath name the window by
    /// the chosen tab, and a stack in a tab by its top page.
    func testTabsPushedOntoAStackKeepTheTitleBeneathThem() throws {
        let runtime = runtime(node("window", .window, [.title: .string("Window")], children: [
            node("stack", .navigationStack, children: [
                node("group", .page, [.title: .string("Items and Cards")]),
                node("tabs", .tabbedView, [.currentPage: .number(1)], children: [
                    node("one", .page, [.title: .string("Example 1")]),
                    node("two", .page, [.title: .string("Example 2")]),
                ]),
            ]),
            node("alone", .tabbedView, children: [node("tab", .page, [.title: .string("Tab")])]),
            node("stacked", .tabbedView, children: [
                node("inner", .navigationStack, children: [node("top", .page, [.title: .string("Top")])]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let title = { (id: String) in WindowChrome(window: root, arrangement: root.first(id: .manual(id))).title }

        XCTAssertEqual(title("stack"), "Items and Cards", "the page the tabs were pushed onto")
        XCTAssertEqual(title("alone"), "Tab", "the chosen tab, where nothing lies beneath")
        XCTAssertEqual(title("stacked"), "Top", "a stack in a tab names the window by its top page")
    }

    /// Tabs pushed onto a stack are its last place: a title of their own names the window, never what the tabs show.
    /// A window's own tabs name it by the chosen tab, and a stack in the chosen tab by its top page, titled or not.
    func testTabsWithATitleNameTheWindowByItOnAStack() throws {
        let runtime = runtime(node("window", .window, [.title: .string("Window")], children: [
            node("stack", .navigationStack, children: [
                node("group", .page, [.title: .string("Items and Cards")]),
                node("tabs", .tabbedView, [.title: .string("ItemsView")], children: [
                    node("one", .page, [.title: .string("Example 1")]),
                ]),
            ]),
            node("alone", .tabbedView, [.title: .string("Tabs")], children: [
                node("tab", .page, [.title: .string("Tab")]),
            ]),
            node("stacked", .tabbedView, [.title: .string("Tabs")], children: [
                node("inner", .navigationStack, children: [node("top", .page, [.title: .string("Top")])]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let title = { (id: String) in WindowChrome(window: root, arrangement: root.first(id: .manual(id))).title }

        XCTAssertEqual(title("stack"), "ItemsView", "the pushed tabs' own title")
        XCTAssertEqual(title("alone"), "Tab", "a window's own tabs: the chosen tab")
        XCTAssertEqual(title("stacked"), "Top", "a stack in a tab names the window by its top page")
    }

    /// A menu walks its items, separators and submenus in order, each with its caption and whether it can be chosen;
    /// a bar holds only its menus.
    func testAMenuIsWalkedInOrder() throws {
        let runtime = runtime(node("bar", .menuBar, children: [
            node("file", .menu, [.text: .string("File")], children: [
                node("open", .menuItem, [.text: .string("Open"), .icon: .string("folder")]),
                node("line", .menuSeparator),
                node("erase", .menuItem, [.text: .string("Erase"), .isDestructive: .bool(true), .icon: .string("")]),
                node("recent", .menu, [.text: .string("Recent")], children: [
                    node("one", .menuItem, [.text: .string("One"), .isEnabled: .bool(false)]),
                ]),
            ]),
            node("stray", .menuItem),
        ])) { _ in }

        let menus = MenuEntry.menus(of: try XCTUnwrap(runtime.tree.root))
        XCTAssertEqual(menus.map(\.title), ["File"], "the bar holds only its menus")
        let file = try XCTUnwrap(menus.first).entries
        XCTAssertEqual(file.map(\.kind), [.item, .separator, .item, .submenu])
        XCTAssertEqual(file.map(\.title), ["Open", "", "Erase", "Recent"])
        XCTAssertEqual(file.map(\.icon), ["folder", nil, nil, nil], "an empty picture is none")
        XCTAssertEqual(file.map(\.isDestructive), [false, false, true, false])
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
            _ = presentation.show(try XCTUnwrap(runtime.tree.root), in: runtime.lifecycle)
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

/// A native half that says, as each tabbed view is applied, whether its tabs stand in the window.
@MainActor
private final class TabsReading: NativeElement {
    unowned let element: MountedElement
    let read: (String, Bool) -> Void
    let presentsView = true

    init(_ element: MountedElement, read: @escaping (String, Bool) -> Void) {
        self.element = element
        self.read = read
    }

    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        guard element.type == .tabbedView, case .manual(let id) = element.id else { return }
        read(id, element.tabsStandInWindow)
    }

    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func presentFrame(_ changed: Set<Prop>) {}
    func arrangeChildren() {}
    func leave() {}
}
