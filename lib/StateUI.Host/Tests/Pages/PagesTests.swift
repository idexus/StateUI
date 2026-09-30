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

    /// The chrome takes the visible path's actions, the overflow apart, the way back's words from the page beneath,
    /// the title bar's content over the page's title view, and the stack's colour first.
    func testTheChromeIsComposedFromWhatTheWindowShows() throws {
        let item = { (id: String, overflow: Bool) in
            self.node(id, .toolbarItem, [
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
                    node("items", .toolbarItems, children: [item("first", false), item("more", true), item("next", false)]),
                    node("view", .titleView, children: [node("words", .label)]),
                ]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)

        let chrome = WindowChrome(window: root, arrangement: root.first(id: .manual("stack")))
        XCTAssertEqual(chrome.title, "Detail")
        XCTAssertEqual(chrome.back?.title, "Home")
        XCTAssertEqual(chrome.actions.primary.map(\.id), [.manual("first"), .manual("next")])
        XCTAssertEqual(chrome.actions.overflow.map(\.id), [.manual("more")])
        XCTAssertEqual(chrome.center?.id, .manual("search"), "the title bar's content over the page's title view")
        XCTAssertEqual(chrome.background, .string("stack"))
        XCTAssertNil(chrome.sidebarToggle)
    }

    /// A toolbar group of `items`, at `side`, in `order`.
    private func toolbarGroup(
        _ id: String, _ items: [HostPatch], side: ToolbarSide = .trailing, order: Double = 0
    ) -> HostPatch {
        node(id, .toolbarItems, [.side: .enumeration(side.rawValue), .order: .number(order)], children: items)
    }

    /// An action captioned `text`, where one is said.
    private func toolbarAction(_ id: String, _ text: String? = nil) -> HostPatch {
        node(id, .toolbarItem, text.map { [.text: .string($0)] } ?? [:])
    }

    /// A window's split view declaring `outer` around a stack whose top page's content declares `inner`.
    private func pathWindow(outer: [HostPatch], inner: [HostPatch]) -> HostPatch {
        node("window", .window, children: [
            node("split", .splitView, children: [
                node("menu", .page),
                node("stack", .navigationStack, children: [
                    node("home", .page),
                    node("detail", .page, children: [node("content", .vStack, children: [node("words", .label)] + inner)]),
                ]),
            ] + outer),
        ])
    }

    /// Each declaration is a group; the page's own stand nearer the title and the outer ones keep their place at the
    /// edge - last at the trailing edge, first at the leading - and a group's order moves it.
    func testTheActionsOfAPathStandInGroups() throws {
        let runtime = runtime(pathWindow(
            outer: [
                toolbarGroup("window", [toolbarAction("inspector"), toolbarAction("home")]),
                toolbarGroup("start", [toolbarAction("compose")], side: .leading),
            ],
            inner: [
                toolbarGroup("page", [toolbarAction("save"), toolbarAction("add")]),
                toolbarGroup("later", [toolbarAction("share")], order: 1),
                toolbarGroup("near", [toolbarAction("filter")], side: .leading),
            ])) { _ in }
        let page = try XCTUnwrap(runtime.tree.root?.first(id: .manual("detail")))

        let actions = page.chromeActions
        XCTAssertEqual(actions.trailing.map { $0.map(\.id) }, [
            [.manual("save"), .manual("add")], [.manual("inspector"), .manual("home")], [.manual("share")],
        ])
        XCTAssertEqual(actions.leading.map { $0.map(\.id) }, [[.manual("compose")], [.manual("filter")]])
        XCTAssertEqual(actions.primary.map(\.id), [
            .manual("save"), .manual("add"), .manual("inspector"), .manual("home"), .manual("share"),
        ])
    }

    /// A group of an id declared further in joins the one around it, nearer the title; an action of an id declared
    /// further in stands in the place of the outer one, which leaves; and a group left with nothing is none.
    func testAGroupJoinsTheOneOfItsIdAndAnActionStandsInItsPlace() throws {
        let runtime = runtime(pathWindow(
            outer: [toolbarGroup("window", [toolbarAction("inspector"), toolbarAction("save", "Save")])],
            inner: [
                toolbarGroup("window", [toolbarAction("help")]),
                toolbarGroup("own", [toolbarAction("save", "Save this page")]),
            ])) { _ in }
        let page = try XCTUnwrap(runtime.tree.root?.first(id: .manual("detail")))

        let actions = page.chromeActions
        XCTAssertEqual(actions.trailing.map { $0.map(\.id) }, [[.manual("help"), .manual("inspector"), .manual("save")]])
        XCTAssertEqual(actions.primary.last?.value(.text)?.string, "Save this page")
    }

    /// A page hiding its bar shows no actions; a sheet's page takes nothing from the window it stands over.
    func testAHiddenBarAndASheetTakeNothingFromAround() throws {
        var window = pathWindow(outer: [toolbarGroup("window", [toolbarAction("inspector")])], inner: [])
        guard case .arranged(var children) = window.children else { return XCTFail("a window of children") }
        children.append(node("modal", .modalStack, children: [
            node("sheet", .page, children: [toolbarGroup("mine", [toolbarAction("done")])]),
        ]))
        window.children = .arranged(children)
        let runtime = runtime(window) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(try XCTUnwrap(root.first(id: .manual("sheet"))).chromeActions.primary.map(\.id), [.manual("done")])
        XCTAssertEqual(try XCTUnwrap(root.first(id: .manual("home"))).chromeActions.primary.map(\.id), [.manual("inspector")])

        let bare = self.runtime(node("page", .page, [.hasNavigationBar: .bool(false)], children: [
            toolbarGroup("mine", [toolbarAction("done")]),
        ])) { _ in }
        XCTAssertTrue(try XCTUnwrap(bare.tree.root).chromeActions.primary.isEmpty)
    }

    /// A stack declaring `outer` over `pages`, each page's content declaring its own group.
    private func stackWindow(outer: [HostPatch], pages: [(id: String, group: [HostPatch])]) -> HostPatch {
        node("window", .window, children: [
            node("stack", .navigationStack, children: pages.map { page in
                node(page.id, .page, children: [
                    node("\(page.id).content", .vStack, children: page.group.isEmpty ? [] : [
                        toolbarGroup("\(page.id).group", page.group),
                    ]),
                ])
            } + outer),
        ])
    }

    /// A page pushed onto a stack brings its actions nearer the title, and taken away takes them with it: the stack's
    /// own stand as they stood - nothing restored, nothing left behind.
    func testAPushedPagesActionsComeAndGoWithIt() throws {
        let outer = [toolbarGroup("shared", [toolbarAction("home")])]
        let runtime = runtime(stackWindow(outer: outer, pages: [("first", [toolbarAction("add")])])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let top = { WindowChrome(window: root, arrangement: root.first(id: .manual("stack"))).actions.primary.map(\.id) }
        XCTAssertEqual(top(), [.manual("add"), .manual("home")])

        runtime.tree.apply(stackWindow(outer: outer, pages: [
            ("first", [toolbarAction("add")]), ("second", [toolbarAction("share")]),
        ]), complete: false)
        XCTAssertEqual(top(), [.manual("share"), .manual("home")], "the pushed page's own, the stack's in place")

        runtime.tree.apply(stackWindow(outer: outer, pages: [("first", [toolbarAction("add")])]), complete: false)
        XCTAssertEqual(top(), [.manual("add"), .manual("home")], "as it was before the push")
        XCTAssertNil(root.first(id: .manual("share")), "the popped page's action left the tree")
    }

    /// An action changed, added or removed - on the page or on the stack around it - and a group taken away are
    /// composed again from what stands.
    func testAChangedAddedOrRemovedActionIsComposedAgain() throws {
        let runtime = runtime(stackWindow(
            outer: [toolbarGroup("shared", [toolbarAction("home", "Home")])],
            pages: [("page", [toolbarAction("add", "Add")])])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let page = try XCTUnwrap(root.first(id: .manual("page")))
        let words = { page.chromeActions.primary.map { $0.value(.text)?.string ?? "" } }
        XCTAssertEqual(words(), ["Add", "Home"])

        runtime.tree.apply(stackWindow(
            outer: [toolbarGroup("shared", [toolbarAction("home", "Start")])],
            pages: [("page", [toolbarAction("add", "Add"), toolbarAction("share", "Share")])]), complete: false)
        XCTAssertEqual(words(), ["Add", "Share", "Start"], "one added on the page, one renamed on the stack")

        runtime.tree.apply(stackWindow(
            outer: [toolbarGroup("shared", [toolbarAction("home", "Start")])],
            pages: [("page", [toolbarAction("share", "Share")])]), complete: false)
        XCTAssertEqual(words(), ["Share", "Start"], "one removed from the page")

        runtime.tree.apply(stackWindow(outer: [], pages: [("page", [toolbarAction("share", "Share")])]), complete: false)
        XCTAssertEqual(words(), ["Share"], "the stack's group taken away")
        XCTAssertTrue(try XCTUnwrap(root.first(id: .manual("stack"))).slots.isEmpty)
    }

    /// A sparse patch naming an arrangement's slot reaches it where it stands, apart from the pages.
    func testASparsePatchReachesAnArrangementsSlot() throws {
        let runtime = runtime(stackWindow(
            outer: [toolbarGroup("shared", [toolbarAction("home", "Home")])], pages: [("page", [])])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)

        var window = HostPatch(id: .manual("window"), type: .window)
        var stack = HostPatch(id: .manual("stack"), type: .navigationStack)
        var group = HostPatch(id: .manual("shared"), type: .toolbarItems)
        var home = HostPatch(id: .manual("home"), type: .toolbarItem)
        home.properties = [.text: .string("Start")]
        group.children = .changed([home])
        stack.children = .changed([group])
        window.children = .changed([stack])
        runtime.tree.apply(window, complete: false)

        let page = try XCTUnwrap(root.first(id: .manual("page")))
        XCTAssertEqual(page.chromeActions.primary.map { $0.value(.text)?.string }, ["Start"])
        XCTAssertEqual(try XCTUnwrap(root.first(id: .manual("stack"))).children.map(\.id), [.manual("page")])
    }

    /// Tabs: the chosen tab's actions stand with those the tabbed view declares around every tab, and choosing
    /// another tab composes the chrome from it.
    func testTheChosenTabsActionsStandWithTheTabs() throws {
        let tabs = { (chosen: Double) in
            self.node("window", .window, children: [
                self.node("tabs", .tabbedView, [.currentPage: .number(chosen)], children: [
                    self.node("one", .page, children: [self.toolbarGroup("one.group", [self.toolbarAction("first")])]),
                    self.node("two", .page, children: [self.toolbarGroup("two.group", [self.toolbarAction("second")])]),
                    self.toolbarGroup("all", [self.toolbarAction("everywhere")]),
                ]),
            ])
        }
        let runtime = runtime(tabs(0)) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let shown = { WindowChrome(window: root, arrangement: root.first(id: .manual("tabs"))).actions.primary.map(\.id) }
        XCTAssertEqual(shown(), [.manual("first"), .manual("everywhere")])

        runtime.tree.apply(tabs(1), complete: false)
        XCTAssertEqual(shown(), [.manual("second"), .manual("everywhere")])
        XCTAssertEqual(try XCTUnwrap(root.first(id: .manual("tabs"))).children.count, 2, "two tabs, no third")
    }

    /// A split view's sidebar starts a path of its own: what the split view and the arrangements around it declare
    /// stands on the detail's bar, never on the sidebar's.
    func testASidebarTakesNothingFromAroundItsSplitView() throws {
        let runtime = runtime(pathWindow(outer: [toolbarGroup("window", [toolbarAction("inspector")])], inner: [])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(try XCTUnwrap(root.first(id: .manual("home"))).chromeActions.primary.map(\.id), [.manual("inspector")])
        XCTAssertTrue(try XCTUnwrap(root.first(id: .manual("menu"))).chromeActions.primary.isEmpty, "the sidebar's bar")
    }

    /// The title view declared innermost on a page's path stands in its title's place: the page's own, else the one
    /// its stack declares.
    func testTheInnermostTitleViewStandsInTheTitlesPlace() throws {
        let runtime = runtime(node("window", .window, children: [
            node("stack", .navigationStack, children: [
                node("home", .page),
                node("detail", .page, children: [
                    node("content", .vStack, children: [node("view", .titleView, children: [node("own", .label)])]),
                ]),
                node("outer", .titleView, children: [node("shared", .label)]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(root.first(id: .manual("detail"))?.chromeTitleView?.id, .manual("own"))
        XCTAssertEqual(root.first(id: .manual("home"))?.chromeTitleView?.id, .manual("shared"))
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

    /// An arrangement's children are its pages: what it declares - its actions, its menus, its title view - is
    /// never its top page, and a search still finds it.
    func testAnArrangementsDeclarationsAreNotItsPages() throws {
        let runtime = runtime(stackWindow([
            node("a", .page), node("b", .page),
            node("items", .toolbarItems, children: [node("save", .toolbarItem)]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let stack = try XCTUnwrap(root.first(id: .manual("stack")))

        XCTAssertEqual(stack.children.map(\.id), [.manual("a"), .manual("b")])
        XCTAssertEqual(stack.slots.map(\.id), [.manual("items")])
        XCTAssertEqual(stack.visiblePage?.id, .manual("b"))
        XCTAssertNotNil(root.first(id: .manual("save")))
    }

    /// A declaration furnishes the chrome and stands in no room: a page, a stack or any element it is declared on
    /// places every child but it.
    func testNoElementPlacesWhatIsDeclaredOnIt() throws {
        for type in [NodeType.page, .vStack] {
            let runtime = runtime(node("declarer", type, children: [
                node("items", .toolbarItems),
                node("view", .titleView, children: [node("field", .textField)]),
                node("words", .label),
            ])) { _ in }
            let declarer = try XCTUnwrap(runtime.tree.root)

            XCTAssertEqual(declarer.arrangedChildren.map(\.id), [.manual("words")], "\(type)")
        }
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
