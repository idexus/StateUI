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

    /// A window's pages are found in the tree's order, a stack's covered pages among them.
    func testAWindowsPagesAreFoundInTheTreesOrder() throws {
        let runtime = HostRuntime.still()
        let stack = node("stack", .navigationStack, children: [
            node("root", .page, children: [node("words", .text)]), node("pushed", .page),
        ])
        runtime.tree.apply(node("window", .window, children: [stack]), complete: true)

        XCTAssertEqual(try XCTUnwrap(runtime.tree.root).pages.map(\.id), [.manual("root"), .manual("pushed")])
    }

    /// A sheet has no bar of its own: a stack on its visible path brings one, where its top page keeps it.
    func testASheetShowsABarOnlyWhereAStackBringsOne() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(node("window", .window, children: [
            node("page", .page),
            node("stack", .navigationStack, children: [node("root", .page)]),
            node("bare", .navigationStack, children: [node("hidden", .page, [.showsNavigationBar: .bool(false)])]),
            node("split", .splitView, children: [
                node("sidebar", .page), node("detail", .navigationStack, children: [node("top", .page)]),
            ]),
        ]), complete: true)
        let root = try XCTUnwrap(runtime.tree.root)
        func brings(_ id: String) throws -> Bool { try XCTUnwrap(root.first(id: .manual(id))).bringsABar }

        XCTAssertFalse(try brings("page"), "a page alone")
        XCTAssertTrue(try brings("stack"))
        XCTAssertFalse(try brings("bare"), "a stack whose top page hides its bar")
        XCTAssertTrue(try brings("split"), "a stack in the detail")
    }

    /// The bar a stack brings to a sheet offers a button closing it, but where the page it shows says it does not.
    func testASheetsStackOffersItsCloseButtonButWhereThePageSaysNot() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(node("window", .window, children: [
            node("beneath", .navigationStack, children: [node("home", .page, children: [
                node("plain", .sheet, children: [node("page", .page)]),
                node("stacked", .sheet, children: [node("stack", .navigationStack, children: [node("root", .page)])]),
                node("finishing", .sheet, children: [
                    node("closed", .navigationStack, children: [node("finish", .page, [.showsCloseButton: .bool(false)])]),
                ]),
            ])]),
        ]), complete: true)
        let root = try XCTUnwrap(runtime.tree.root)
        func element(_ id: String) throws -> MountedElement { try XCTUnwrap(root.first(id: .manual(id))) }

        XCTAssertFalse(try element("page").offersClose, "no bar, no button")
        XCTAssertTrue(try element("stack").offersClose)
        XCTAssertTrue(try element("root").offersItsSheetsClose, "on the bar over the stack's page")
        XCTAssertFalse(try element("closed").offersClose, "the page says it offers none")
        XCTAssertFalse(try element("home").offersItsSheetsClose, "a stack in no sheet")
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

    /// A tabbed view's tabs stand in the window's row down its stacks and its split view details - the page the
    /// window shows - and nowhere else: never in a sidebar, a tab of another or a sheet.
    func testTabsStandInTheWindowDownItsStacksAndDetails() throws {
        let tabs = { (id: String) in self.node(id, .tabView, children: [self.node("\(id).page", .page)]) }
        let runtime = runtime(node("window", .window, children: [
            node("split", .splitView, children: [
                tabs("sidebar"),
                node("stack", .navigationStack, children: [node("detail", .tabView, children: [
                    tabs("inner"), node("detail.page", .page, children: [presenting(tabs("sheet"))]),
                ])]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let stands = { (id: String) in root.first(id: .manual(id))?.tabsStandInWindow }

        XCTAssertEqual(stands("detail"), true, "down a split view's detail and a stack")
        XCTAssertTrue(root.first(id: .manual("split"))?.visibleTabView === root.first(id: .manual("detail")))
        XCTAssertEqual(stands("sidebar"), false, "a sidebar keeps its own row")
        XCTAssertEqual(stands("inner"), false, "a tab of another keeps its own row")
        XCTAssertEqual(stands("sheet"), false, "a sheet keeps its own row")

        let bare = self.runtime(node("window", .window, children: [tabs("root")])) { _ in }
        XCTAssertEqual(bare.tree.root?.first(id: .manual("root"))?.tabsStandInWindow, true, "the window's page")
    }

    /// Every tabbed view an arrangement of pages shows - through its pages and the arrangements in them - is what the
    /// chrome paints the bars' colors on again; none in a page's content, and a sheet's from its own page.
    func testTheTabbedViewsAnArrangementShowsAreFoundThroughItsPages() throws {
        let tabs = { (id: String) in self.node(id, .tabView, children: [self.node("\(id).page", .page)]) }
        let runtime = runtime(node("window", .window, children: [
            node("split", .splitView, children: [
                tabs("sidebar"),
                node("stack", .navigationStack, children: [node("detail", .tabView, children: [
                    tabs("inner"), node("detail.page", .page, children: [presenting(tabs("sheet"))]),
                ])]),
            ]),
        ])) { _ in }
        let split = try XCTUnwrap(runtime.tree.root?.first(id: .manual("split")))

        XCTAssertEqual(split.tabViewsShown.map(\.id), [.manual("sidebar"), .manual("detail"), .manual("inner")])
        XCTAssertEqual(try XCTUnwrap(split.first(id: .manual("sheet"))).tabViewsShown.map(\.id), [.manual("sheet")])
    }

    /// A page's bar says its title; a sidebar's page that says none - itself, or the root of a stack there - shows the
    /// application's name, as a sidebar stands under it; any other page says none.
    func testAnUntitledSidebarShowsTheApplicationsName() throws {
        let titled = [Prop.title: HostValue.string("Folders")]
        let runtime = runtime(node("window", .window, children: [
            node("split", .splitView, children: [
                node("menu", .navigationStack, children: [node("sidebar", .page)]),
                node("detail", .page),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let title = { (id: String) in root.first(id: .manual(id))?.barTitle(applicationName: "Notes") }

        XCTAssertEqual(title("sidebar"), "Notes", "an untitled sidebar")
        XCTAssertEqual(title("detail"), "", "an untitled detail")

        let named = self.runtime(node("window", .window, children: [
            node("split", .splitView, children: [node("sidebar", .page, titled), node("detail", .page)]),
        ])) { _ in }
        XCTAssertEqual(named.tree.root?.first(id: .manual("sidebar"))?.barTitle(applicationName: "Notes"), "Folders")
    }

    /// A stack shows its bar over a page that keeps one, and over tabs only where the chosen tab stands in no stack of
    /// its own, whose bar is the one.
    func testAStacksBarShowsOnlyWhereNoStackBelowHasOne() throws {
        let hidden = [Prop.showsNavigationBar: HostValue.bool(false)]
        let runtime = runtime(node("window", .window, children: [node("stack", .navigationStack, children: [
            node("page", .page),
            node("bare", .page, hidden),
            node("pages", .tabView, children: [node("tab", .page)]),
            node("stacks", .tabView, children: [node("inner", .navigationStack, children: [node("top", .page)])]),
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
        let tabs = { (id: String) in self.node(id, .tabView, children: [self.node("\(id).page", .page)]) }

        runtime.tree.apply(
            node("window", .window, children: [node("split", .splitView, children: [tabs("sidebar"), tabs("detail")])]),
            complete: true)

        XCTAssertEqual(read, ["sidebar": false, "detail": true])
    }

    /// A tab the tree asks for anew is chosen; the user's choice stands where it is another tab there is.
    /// A tab the user chooses on a tab view with no selection bound tells its pages at once: the phases the choice
    /// queues take a turn of their own, whatever else the choice carries.
    func testATabChosenWithNothingBoundTellsItsPagesAtOnce() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(node("window", .window, children: [node("tabs", .tabView, children: [
            node("a", .page, events: [.appearing: 2, .disappearing: 3]),
            node("b", .page, events: [.appearing: 4, .disappearing: 5]),
        ])]), complete: true)
        _ = WindowPresentation().show(try XCTUnwrap(runtime.tree.root), in: runtime.lifecycle)

        let tabs = try XCTUnwrap(runtime.tree.root?.first(id: .manual("tabs")))
        runtime.tabChosen(tabs, from: 0, to: 1)

        XCTAssertFalse(runtime.pump.handlers.hasQueued, "the pages' phases wait for a turn nothing takes")
    }

    /// A tab the user chooses shows another page in the window: the host shows its chrome again, as a render
    /// changing the chrome has it - the page's title, its bar - whatever the choice carries.
    func testATabChosenShowsTheChromeAgain() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(node("window", .window, children: [node("tabs", .tabView, children: [
            node("a", .page), node("b", .page),
        ])]), complete: true)
        _ = runtime.tree.takeChromeTouched()
        let presented = Presented()
        runtime.presenter = presented

        runtime.tabChosen(try XCTUnwrap(runtime.tree.root?.first(id: .manual("tabs"))), from: 0, to: 1)

        XCTAssertEqual(presented.chrome, [true])
    }

    /// The user took a stack's top pages away through the toolkit - its back button, a swipe - leaving `staying`
    /// pages: its path is told how long it is now, by the rule every host shares.
    func testAStackThePlatformPoppedShortensItsPath() throws {
        stateUIUseApp(PoppedPathApplication())
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let stack = { runtime.tree.root?.first(type: .navigationStack) }
        XCTAssertEqual(stack()?.children.count, 3, "the root and two pages")

        runtime.stackPopped(try XCTUnwrap(stack()), staying: 2)
        runtime.pump.turn()

        XCTAssertEqual(stack()?.children.count, 2, "the root and the first page")
    }

    /// The user taking a stack's shown top page away - the event that took it carrying a depth - hears it disappear
    /// as it leaves, then that it is destroyed, as one the program takes away does.
    func testAPageTheUserPopsHearsItDisappears() throws {
        PhaseLog.said = []
        stateUIUseApp(PhaseLogApplication())
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let stack = { runtime.tree.root?.first(type: .navigationStack) }
        try XCTUnwrap(stack()).setPagePresented(true, reason: .window)
        runtime.pump.turn()
        XCTAssertTrue(PhaseLog.said.contains("Pushed appearing"), "\(PhaseLog.said)")

        PhaseLog.said = []
        runtime.stackPopped(try XCTUnwrap(stack()), staying: 1)
        runtime.pump.turn()

        XCTAssertEqual(stack()?.children.count, 1)
        XCTAssertEqual(Array(PhaseLog.said.prefix(2)), ["Pushed disappearing", "Pushed destroying"], "\(PhaseLog.said)")
    }

    /// What the host was asked to show of the chrome, in turn.
    private final class Presented: HostPresenter {
        var chrome: [Bool] = []
        func presentRendered(touchedChrome: Bool) { chrome.append(touchedChrome) }
        func presentFrame(movedChrome: Bool) {}
        func perform(_ call: HostActCall) {}
        func open(link address: String) {}
        func focus(_ element: MountedElement) {}
    }

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

        // The tabs shrank under a choice: the tab shown before is the one there is, not the one that went.
        var shrunk = TabChoice()
        _ = shrunk.request(4)
        XCTAssertEqual(shrunk.choose(0, of: 3), 2, "the last of the three shown, not the fifth that went")
        XCTAssertEqual(shrunk.choose(2, of: 3), 0)
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
        XCTAssertFalse(adaptation.decided, "a host still measures the room")
        XCTAssertTrue(adaptation.room(900, breakpoint: 700, shown: false))
        XCTAssertTrue(adaptation.decided, "a host measures it no more")
        XCTAssertFalse(adaptation.room(900, breakpoint: 700, shown: false), "decided once")

        var narrow = SidebarAdaptation()
        XCTAssertFalse(narrow.room(500, breakpoint: 700, shown: false))
    }

    /// A sidebar stands beside the detail from the breakpoint and over it below; one shown beside the detail closes
    /// as the window narrows it over, and nothing opens it as the window widens.
    func testASidebarBesideTheDetailClosesAsTheWindowNarrowsItOver() {
        var adaptation = SidebarAdaptation()
        XCTAssertEqual(adaptation.place(900, breakpoint: 700, shown: true).beside, true)
        let narrowed = adaptation.place(600, breakpoint: 700, shown: true)
        XCTAssertFalse(narrowed.beside)
        XCTAssertTrue(narrowed.closes, "beside, then over")
        XCTAssertFalse(adaptation.place(500, breakpoint: 700, shown: true).closes, "over already: the user's to close")
        XCTAssertFalse(adaptation.place(900, breakpoint: 700, shown: false).closes)
        XCTAssertFalse(adaptation.place(600, breakpoint: 700, shown: false).closes, "a hidden one has nothing to close")

        var first = SidebarAdaptation()
        XCTAssertFalse(first.place(600, breakpoint: 700, shown: true).closes, "placed over from the start")
    }

    /// An action's words stand on the bar beside its picture only where it says so, and always where it has none.
    func testAnActionShowsItsWordsBesideItsPictureWhereItSaysSo() throws {
        let runtime = runtime(node("page", .page, children: [
            node("items", .toolbarGroup, children: [
                node("words", .toolbarButton, [.text: .string("Words")]),
                node("picture", .toolbarButton, [.text: .string("Picture"), .icon: .string("add")]),
                node("both", .toolbarButton, [.text: .string("Both"), .icon: .string("add"), .showsText: .bool(true)]),
                node("hidden", .toolbarButton, [.text: .string("Hidden"), .showsText: .bool(false)]),
            ]),
        ])) { _ in }
        let page = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(page.chromeActions.primary.map(\.showsActionWords), [true, false, true, true])
    }

    /// Choosing a setting's entry turns it in one transaction of the user's: its state and its own handler's write
    /// show in one render.
    func testChoosingACheckedEntryRendersOnce() throws {
        stateUIUseApp(CheckedApplication())
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let entry = try XCTUnwrap(runtime.tree.root?.first(type: .menuToggle))
        let renders = runtime.core.tally.renders

        entry.chosen(in: runtime)

        XCTAssertEqual(runtime.core.tally.renders, renders + 1, "the turn and its handler render together")
        XCTAssertEqual(runtime.tree.root?.first(type: .text)?.value(.text), .string("turns 1, bold true"))
    }

    /// The back button's words, where the page below says none, are the library's own in the system's language.
    func testTheBackButtonSpeaksTheSystemsLanguage() throws {
        let runtime = runtime(node("window", .window, children: [
            node("stack", .navigationStack, children: [
                node("home", .page, [.title: .string("Home")]),
                node("detail", .page, [.title: .string("Detail")]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let english = try XCTUnwrap(HostLocaleInfo(words: ["en", "GB", "en-GB", "Europe/London", "1", "1", "1", "0"]))
        let polish = try XCTUnwrap(HostLocaleInfo(words: ["pl", "PL", "pl-PL", "Europe/Warsaw", "1", "1", "1", "0"]))
        defer { runtime.core.setLocaleInfo(english) }

        runtime.core.setLocaleInfo(polish)
        let chrome = WindowChrome(window: root, arrangement: root.first(id: .manual("stack")))

        XCTAssertEqual(chrome.back?.1, "Wstecz")
    }

    /// A page saying it shows no title still names the window; the chrome shows no title for it.
    func testAPageShowingNoTitleStillNamesTheWindow() throws {
        let runtime = runtime(node("window", .window, children: [
            node("stack", .navigationStack, children: [
                node("home", .page, [.title: .string("Home"), .showsTitle: .bool(false)]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)

        let chrome = WindowChrome(window: root, arrangement: root.first(id: .manual("stack")))
        XCTAssertEqual(chrome.title, "Home", "the window's name")
        XCTAssertFalse(chrome.showsTitle)
        XCTAssertTrue(WindowChrome.pageValues.contains(.showsTitle), "the chrome follows it")
    }

    /// The chrome takes the visible path's actions, the overflow apart, the way back's words from the page beneath,
    /// the page's title view, and the stack's color.
    func testTheChromeIsComposedFromWhatTheWindowShows() throws {
        let runtime = runtime(node("window", .window, children: [
            node("stack", .navigationStack, [.barBackground: .string("stack")], children: [
                node("home", .page, [.backButtonTitle: .string("Home")]),
                node("detail", .page, [.title: .string("Detail")], children: [
                    toolbarGroup("items", [toolbarAction("first"), toolbarAction("next")]),
                    toolbarGroup("tucked", [toolbarAction("more")], at: .overflow),
                    node("view", .titleView, children: [node("words", .text)]),
                ]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)

        let chrome = WindowChrome(window: root, arrangement: root.first(id: .manual("stack")))
        XCTAssertEqual(chrome.title, "Detail")
        XCTAssertEqual(chrome.back?.title, "Home")
        XCTAssertEqual(chrome.actions.primary.map(\.id), [.manual("first"), .manual("next")])
        XCTAssertEqual(chrome.actions.overflow.map(\.id), [.manual("more")])
        XCTAssertEqual(chrome.center?.id, .manual("words"), "the page's title view")
        XCTAssertEqual(chrome.background, .string("stack"))
        XCTAssertNil(chrome.splitView)
        XCTAssertFalse(chrome.showsSidebarToggle)
    }

    /// A split view the window shows stands under the chrome, and the chrome offers its sidebar's toggle unless the
    /// split view says it offers none.
    func testASplitViewOffersItsToggleUnlessItSaysNot() throws {
        for (said, offered) in [(nil, true), (.bool(true), true), (.bool(false), false)] as [(HostValue?, Bool)] {
            let runtime = runtime(node("window", .window, children: [
                node("split", .splitView, said.map { [.showsSidebarToggle: $0] } ?? [:], children: [
                    node("sidebar", .page), node("detail", .page),
                ]),
            ])) { _ in }
            let root = try XCTUnwrap(runtime.tree.root)

            let chrome = WindowChrome(window: root, arrangement: root.first(id: .manual("split")))
            XCTAssertEqual(chrome.splitView?.id, .manual("split"), "\(said as Any)")
            XCTAssertEqual(chrome.showsSidebarToggle, offered, "\(said as Any)")
            XCTAssertEqual(chrome.splitView?.offersSidebarToggle, offered, "a host drawing its own bars asks it alike")
        }
    }

    /// A toolbar group of `items`, at `side`, in `order`.
    private func toolbarGroup(
        _ id: String, _ items: [HostPatch], at position: ToolbarPosition = .end, order: Double = 0,
        part: ToolbarPart? = nil, hidesWithSidebar: Bool = false
    ) -> HostPatch {
        var properties: [Prop: HostValue] = [.position: .enumeration(position.rawValue), .order: .number(order)]
        if let part { properties[.part] = .enumeration(part.rawValue) }
        if hidesWithSidebar { properties[.hidesWithSidebar] = .bool(true) }
        return node(id, .toolbarGroup, properties, children: items)
    }

    /// An action captioned `text`, where one is said.
    private func toolbarAction(_ id: String, _ text: String? = nil) -> HostPatch {
        node(id, .toolbarButton, text.map { [.text: .string($0)] } ?? [:])
    }

    /// A window's split view declaring `outer` around a stack whose top page's content declares `inner`.
    private func pathWindow(outer: [HostPatch], inner: [HostPatch]) -> HostPatch {
        node("window", .window, children: [
            node("split", .splitView, children: [
                node("menu", .page),
                node("stack", .navigationStack, children: [
                    node("home", .page),
                    node("detail", .page, children: [node("content", .vStack, children: [node("words", .text)] + inner)]),
                ]),
            ] + outer),
        ])
    }

    /// A window's split view whose detail is a stack, its top page's content declaring `outer` and a view deeper in
    /// it `inner`, its sidebar's page `sidebar`; `split` declared on the split view, and `stacked` on the stack, as
    /// no core sends but a host bears; the sidebar shown or not.
    private func pageWindow(
        outer: [HostPatch] = [], inner: [HostPatch] = [], sidebar: [HostPatch] = [], split: [HostPatch] = [],
        stacked: [HostPatch] = [], sidebarShown: Bool = true
    ) -> HostPatch {
        node("window", .window, children: [
            node("split", .splitView, [.showsSidebar: .bool(sidebarShown)], children: [
                node("menu", .page, children: [node("menu.content", .vStack, children: sidebar)]),
                node("stack", .navigationStack, children: [
                    node("home", .page),
                    node("detail", .page, children: [
                        node("content", .vStack, children: [node("deeper", .vStack, children: [node("words", .text)] + inner)]
                            + outer),
                    ]),
                ] + stacked),
            ] + split),
        ])
    }

    /// The ids of what the page `id` shows: each group at the start, "|", at the end, "|", the overflow's sections.
    private func bar(_ id: String, in runtime: HostRuntime) -> String {
        guard let actions = runtime.tree.root?.first(id: .manual(id))?.chromeActions else { return "none" }
        return said(actions)
    }

    /// The ids of `actions`: each group at the start, "|", at the end, "|", the overflow's sections.
    private func said(_ actions: ChromeActions) -> String {
        let groups = { (groups: [[MountedElement]]) in
            groups.map { "[" + $0.map { Self.said($0.id) }.joined(separator: " ") + "]" }.joined(separator: " ")
        }
        return groups(actions.start) + "|" + groups(actions.end) + "|" + groups(actions.overflowSections)
    }

    /// An id as a test wrote it.
    private static func said(_ id: ElementID) -> String {
        if case .manual(let words) = id { return words }
        return "?"
    }

    /// Each declaration is a group; the page's views further in stand nearer the title and those further out keep
    /// their place at the edge - last at the trailing edge, first at the leading - and a group's order moves it.
    func testAPagesActionsStandInGroups() throws {
        let runtime = runtime(pageWindow(
            outer: [
                toolbarGroup("shared", [toolbarAction("inspector"), toolbarAction("home")]),
                toolbarGroup("start", [toolbarAction("compose")], at: .start),
            ],
            inner: [
                toolbarGroup("page", [toolbarAction("save"), toolbarAction("add")]),
                toolbarGroup("later", [toolbarAction("share")], order: 1),
                toolbarGroup("near", [toolbarAction("filter")], at: .start),
            ])) { _ in }

        XCTAssertEqual(bar("detail", in: runtime), "[compose] [filter]|[save add] [inspector home] [share]|")
        let page = try XCTUnwrap(runtime.tree.root?.first(id: .manual("detail")))
        XCTAssertEqual(page.chromeActions.primary.map(\.id), [
            .manual("save"), .manual("add"), .manual("inspector"), .manual("home"), .manual("share"),
        ])
    }

    /// The groups behind the overflow are its sections, in reading order, the outer first.
    func testTheOverflowsGroupsAreItsSections() throws {
        let runtime = runtime(pageWindow(
            outer: [toolbarGroup("outer", [toolbarAction("export")], at: .overflow)],
            inner: [toolbarGroup("inner", [toolbarAction("clear"), toolbarAction("reset")], at: .overflow)])) { _ in }

        XCTAssertEqual(bar("detail", in: runtime), "||[export] [clear reset]")
    }

    /// A page owns its bar's actions, and a split view's stand beside them in their part - by default the detail's -
    /// at the edge; a group standing on a stack, which no core sends, stands on no bar.
    func testEachPageShowsItsOwnAndItsSplitViewsPart() throws {
        let runtime = runtime(pageWindow(
            outer: [toolbarGroup("page", [toolbarAction("more")])],
            sidebar: [toolbarGroup("menu.group", [toolbarAction("folder")])],
            split: [
                toolbarGroup("toSidebar", [toolbarAction("add")], part: .sidebar),
                toolbarGroup("toDetail", [toolbarAction("inspector")]),
            ],
            stacked: [toolbarGroup("stacked", [toolbarAction("lost")])])) { _ in }

        XCTAssertEqual(bar("detail", in: runtime), "|[more] [inspector]|", "the detail's own, then its part's")
        XCTAssertEqual(bar("menu", in: runtime), "|[folder] [add]|", "the sidebar's own, then its part's")
        XCTAssertEqual(bar("home", in: runtime), "|[inspector]|", "a page under the top: its part's alone")
    }

    /// A page's group naming the other part stands there, beside that part's own.
    func testAPagesGroupNamingTheOtherPartStandsThere() throws {
        let runtime = runtime(pageWindow(
            outer: [toolbarGroup("pinned", [toolbarAction("pin")], part: .sidebar)],
            sidebar: [toolbarGroup("menu.group", [toolbarAction("folder")])])) { _ in }

        XCTAssertEqual(bar("menu", in: runtime), "|[folder] [pin]|")
        XCTAssertEqual(bar("detail", in: runtime), "||")
    }

    /// While the sidebar is not shown its part's groups stand at the start of the detail's, the overflow's in its
    /// overflow, or hide with it where they say so.
    func testTheSidebarsGroupsMoveToTheDetailOrHideWithIt() throws {
        let window = { (shown: Bool) in
            self.pageWindow(
                outer: [self.toolbarGroup("page", [self.toolbarAction("more")])],
                split: [
                    self.toolbarGroup("toggle", [self.toolbarAction("add")], part: .sidebar),
                    self.toolbarGroup("tucked", [self.toolbarAction("sort")], at: .overflow, part: .sidebar),
                    self.toolbarGroup("hiding", [self.toolbarAction("filter")], part: .sidebar, hidesWithSidebar: true),
                ],
                sidebarShown: shown)
        }
        let runtime = runtime(window(true)) { _ in }
        XCTAssertEqual(bar("detail", in: runtime), "|[more]|")
        XCTAssertEqual(bar("menu", in: runtime), "|[add] [filter]|[sort]")

        runtime.tree.apply(window(false), complete: false)
        XCTAssertEqual(bar("detail", in: runtime), "[add]|[more]|[sort]", "moved, the hiding one gone")
    }

    /// An action whose part changes stands in the other part, the same element.
    func testAnActionWhosePartChangesStandsInTheOther() throws {
        let window = { (part: ToolbarPart) in
            self.pageWindow(split: [self.toolbarGroup("pin.group", [self.toolbarAction("pin")], part: part)])
        }
        let runtime = runtime(window(.sidebar)) { _ in }
        let pin = try XCTUnwrap(runtime.tree.root?.first(id: .manual("pin")))
        XCTAssertEqual(bar("menu", in: runtime), "|[pin]|")
        XCTAssertEqual(bar("detail", in: runtime), "||")

        runtime.tree.apply(window(.detail), complete: false)
        XCTAssertEqual(bar("menu", in: runtime), "||")
        XCTAssertEqual(bar("detail", in: runtime), "|[pin]|")
        XCTAssertTrue(runtime.tree.root?.first(id: .manual("pin")) === pin, "one element moving")
    }

    /// A window's one chrome shows both parts of its split view's bar: the sidebar's from the sidebar's page while the
    /// sidebar shows, the detail's from the visible page - and, the sidebar hidden, the sidebar's part in the detail's.
    func testAWindowsChromeShowsBothPartsOfItsSplitViewsBar() throws {
        let window = { (shown: Bool) in
            self.pageWindow(
                outer: [self.toolbarGroup("page", [self.toolbarAction("more")])],
                sidebar: [self.toolbarGroup("menu.group", [self.toolbarAction("folder")])],
                split: [self.toolbarGroup("toggle", [self.toolbarAction("add")], part: .sidebar)],
                sidebarShown: shown)
        }
        let runtime = runtime(window(true)) { _ in }
        let chrome = {
            WindowChrome(window: try XCTUnwrap(runtime.tree.root), arrangement: runtime.tree.root?.first(id: .manual("split")))
        }
        XCTAssertEqual(said(try chrome().sidebarActions), "|[folder] [add]|")
        XCTAssertEqual(said(try chrome().actions), "|[more]|")

        runtime.tree.apply(window(false), complete: false)
        XCTAssertEqual(said(try chrome().sidebarActions), "||")
        XCTAssertEqual(said(try chrome().actions), "[add] [folder]|[more]|", "the outer at the start's edge")
    }

    /// A page hiding its bar shows no actions; a sheet's page shows its own, and the page it stands over its own.
    func testAHiddenBarAndASheetShowTheirOwn() throws {
        let runtime = runtime(node("window", .window, children: [
            node("stack", .navigationStack, children: [
                node("home", .page, children: [
                    presenting(node("sheet", .page, children: [toolbarGroup("mine", [toolbarAction("done")])])),
                    toolbarGroup("home.group", [toolbarAction("inspector")]),
                ]),
            ]),
        ])) { _ in }

        XCTAssertEqual(bar("sheet", in: runtime), "|[done]|")
        XCTAssertEqual(bar("home", in: runtime), "|[inspector]|")

        let bare = self.runtime(node("page", .page, [.showsNavigationBar: .bool(false)], children: [
            toolbarGroup("mine", [toolbarAction("done")]),
        ])) { _ in }
        XCTAssertTrue(try XCTUnwrap(bare.tree.root).chromeActions.primary.isEmpty)
    }

    /// A stack over `pages`, each page's content declaring its own group.
    private func stackWindow(pages: [(id: String, group: [HostPatch])]) -> HostPatch {
        node("window", .window, children: [
            node("stack", .navigationStack, children: pages.map { page in
                node(page.id, .page, children: [
                    node("\(page.id).content", .vStack, children: page.group.isEmpty ? [] : [
                        toolbarGroup("\(page.id).group", page.group),
                    ]),
                ])
            }),
        ])
    }

    /// A page pushed onto a stack shows its own actions and none of the page under it; taken away, it takes them
    /// with it, and the page under it shows its own again.
    func testAPushedPagesActionsComeAndGoWithIt() throws {
        let runtime = runtime(stackWindow(pages: [("first", [toolbarAction("add")])])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let top = { WindowChrome(window: root, arrangement: root.first(id: .manual("stack"))).actions.primary.map(\.id) }
        XCTAssertEqual(top(), [.manual("add")])

        runtime.tree.apply(stackWindow(pages: [
            ("first", [toolbarAction("add")]), ("second", [toolbarAction("share")]),
        ]), complete: false)
        XCTAssertEqual(top(), [.manual("share")], "the pushed page's own alone")

        runtime.tree.apply(stackWindow(pages: [("first", [toolbarAction("add")])]), complete: false)
        XCTAssertEqual(top(), [.manual("add")], "as it was before the push")
        XCTAssertNil(root.first(id: .manual("share")), "the popped page's action left the tree")
    }

    /// An action changed, added or removed and a group taken away are composed again from what stands.
    func testAChangedAddedOrRemovedActionIsComposedAgain() throws {
        let runtime = runtime(stackWindow(pages: [("page", [toolbarAction("add", "Add")])])) { _ in }
        let page = try XCTUnwrap(runtime.tree.root?.first(id: .manual("page")))
        let words = { page.chromeActions.primary.map { $0.value(.text)?.string ?? "" } }
        XCTAssertEqual(words(), ["Add"])

        runtime.tree.apply(stackWindow(pages: [
            ("page", [toolbarAction("add", "Plus"), toolbarAction("share", "Share")]),
        ]), complete: false)
        XCTAssertEqual(words(), ["Plus", "Share"], "one added, one renamed")

        runtime.tree.apply(stackWindow(pages: [("page", [toolbarAction("share", "Share")])]), complete: false)
        XCTAssertEqual(words(), ["Share"], "one removed")

        runtime.tree.apply(stackWindow(pages: [("page", [])]), complete: false)
        XCTAssertEqual(words(), [], "the group taken away")
    }

    /// A sparse patch naming an arrangement's slot reaches it where it stands, apart from the pages.
    func testASparsePatchReachesAnArrangementsSlot() throws {
        let runtime = runtime(node("window", .window, children: [
            node("stack", .navigationStack, children: [
                node("page", .page),
                node("title", .titleView, children: [node("words", .text, [.text: .string("Home")])]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)

        var window = HostPatch(id: .manual("window"), type: .window)
        var stack = HostPatch(id: .manual("stack"), type: .navigationStack)
        var title = HostPatch(id: .manual("title"), type: .titleView)
        var words = HostPatch(id: .manual("words"), type: .text)
        words.properties = [.text: .string("Start")]
        title.children = .changed([words])
        stack.children = .changed([title])
        window.children = .changed([stack])
        runtime.tree.apply(window, complete: false)

        let page = try XCTUnwrap(root.first(id: .manual("page")))
        XCTAssertEqual(page.chromeTitleView?.value(.text)?.string, "Start")
        XCTAssertEqual(try XCTUnwrap(root.first(id: .manual("stack"))).children.map(\.id), [.manual("page")])
    }

    /// Tabs: the chosen tab's page shows its own actions, and choosing another tab composes the chrome from it.
    func testTheChosenTabsActionsAreItsOwn() throws {
        let tabs = { (chosen: Double) in
            self.node("window", .window, children: [
                self.node("tabs", .tabView, [.selectedTab: .number(chosen)], children: [
                    self.node("one", .page, children: [self.toolbarGroup("one.group", [self.toolbarAction("first")])]),
                    self.node("two", .page, children: [self.toolbarGroup("two.group", [self.toolbarAction("second")])]),
                ]),
            ])
        }
        let runtime = runtime(tabs(0)) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let shown = { WindowChrome(window: root, arrangement: root.first(id: .manual("tabs"))).actions.primary.map(\.id) }
        XCTAssertEqual(shown(), [.manual("first")])

        runtime.tree.apply(tabs(1), complete: false)
        XCTAssertEqual(shown(), [.manual("second")])
    }

    /// A split view's sidebar stands on its flyout's material over the detail and on its own beside it; one it does
    /// not say is empty - the platform's own.
    func testASidebarStandsOnTheMaterialOfItsPlace() throws {
        let flyout = Material.color(Color(hex: 0x512BD4)).propValue
        let runtime = runtime(node("window", .window, children: [
            node("split", .splitView, [.sidebarOverlayBackground: flyout], children: [node("menu", .page), node("home", .page)]),
        ])) { _ in }
        let split = try XCTUnwrap(runtime.tree.root?.first(id: .manual("split")))

        XCTAssertEqual(split.sidebarMaterial(over: true).paint, flyout)
        XCTAssertTrue(split.sidebarMaterial(over: false).isEmpty, "beside the detail, the platform's own")
    }

    /// A page that says no background stands on the nearest its arrangements declare for their pages - on past a
    /// sheet to the view presenting it - its own winning; a sidebar's page stands on its sidebar's material, and an
    /// arrangement draws none of its own.
    func testAPageStandsOnItsArrangementsBackground() throws {
        let runtime = runtime(node("window", .window, children: [
            node("split", .splitView, [.background: .string("split")], children: [
                node("menu", .page),
                node("stack", .navigationStack, [.background: .string("stack")], children: [
                    node("plain", .page, children: [presenting(node("sheet", .page))]),
                    node("own", .page, [.background: .string("own")]),
                ]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let page = { (id: String) in try XCTUnwrap(root.first(id: .manual(id))) }

        XCTAssertEqual(try page("plain").pageBackground, .string("stack"), "the nearest arrangement's")
        XCTAssertEqual(try page("own").pageBackground, .string("own"), "its own first")
        XCTAssertEqual(try page("sheet").pageBackground, .string("stack"), "past the sheet")
        XCTAssertNil(try page("menu").pageBackground, "a sidebar's page stands on its sidebar's material")
        XCTAssertNil(try page("stack").drawnBackground, "an arrangement's background is its pages'")
        XCTAssertEqual(try page("plain").drawnBackground, .string("stack"))
    }

    /// A surface laid over the page - a sheet, the sidebar over the detail - that the application says nothing of
    /// stands on its window's background, laid over the platform's own surface; a window saying none leaves that
    /// surface alone. Beside the detail the sidebar stays the platform's, and a flyout's own material wins.
    func testASurfaceOverThePageStandsOnTheWindowsBackground() throws {
        let violet = Material.color(Color(hex: 0x2A2154)).propValue
        let flyout = Material.color(Color(hex: 0x251E4C)).propValue
        func window(_ background: PropValue?, flyout: PropValue? = nil) -> HostPatch {
            node("window", .window, [.background: background ?? .nothing], children: [
                node("split", .splitView, [.sidebarOverlayBackground: flyout ?? .nothing], children: [
                    node("menu", .page),
                    node("home", .page, children: [node("presenting", .sheet, children: [node("sheet", .page)])]),
                ]),
            ])
        }
        let runtime = runtime(window(violet)) { _ in }
        func element(_ id: String) throws -> MountedElement {
            try XCTUnwrap(runtime.tree.root?.first(id: .manual(id)))
        }

        XCTAssertEqual(try element("sheet").overlaidGround.paint, violet, "a sheet's page")
        XCTAssertEqual(try element("split").sidebarMaterial(over: true).paint, violet, "the sidebar over the detail")
        XCTAssertTrue(try element("split").sidebarMaterial(over: false).isEmpty, "beside it, the platform's own")
        XCTAssertFalse(try element("split").paintsSidebar, "still the platform's sidebar")

        runtime.tree.apply(window(violet, flyout: flyout), complete: false)
        XCTAssertEqual(try element("split").sidebarMaterial(over: true).paint, flyout, "its own material wins")

        runtime.tree.apply(window(nil), complete: false)
        XCTAssertTrue(try element("sheet").overlaidGround.isEmpty, "the platform's own sheet")
        XCTAssertTrue(try element("split").sidebarMaterial(over: true).isEmpty, "the platform's own drawer")
    }

    /// A split view saying a material for its sidebar, in either place, gives the sidebar to the application to
    /// paint; one saying none leaves it the platform's.
    func testASidebarWithAMaterialOfItsOwnIsTheApplicationsToPaint() throws {
        let beside = Material.color(Color(hex: 0x251E4C)).propValue
        let runtime = runtime(node("window", .window, children: [
            node("painted", .splitView, [.sidebarBackground: beside], children: [node("a", .page), node("b", .page)]),
            node("own", .splitView, children: [node("c", .page), node("d", .page)]),
        ])) { _ in }

        XCTAssertTrue(try XCTUnwrap(runtime.tree.root?.first(id: .manual("painted"))).paintsSidebar)
        XCTAssertFalse(try XCTUnwrap(runtime.tree.root?.first(id: .manual("own"))).paintsSidebar)
    }

    /// The title view declared innermost on a page's path stands in its title's place: the page's own, else the one
    /// its stack declares.
    func testTheInnermostTitleViewStandsInTheTitlesPlace() throws {
        let runtime = runtime(node("window", .window, children: [
            node("stack", .navigationStack, children: [
                node("home", .page),
                node("detail", .page, children: [
                    node("content", .vStack, children: [node("view", .titleView, children: [node("own", .text)])]),
                ]),
                node("outer", .titleView, children: [node("shared", .text)]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(root.first(id: .manual("detail"))?.chromeTitleView?.id, .manual("own"))
        XCTAssertEqual(root.first(id: .manual("home"))?.chromeTitleView?.id, .manual("shared"))
    }

    /// The bottom bar declared innermost on a page's path stands at its foot: the page's own, else its stack's.
    func testTheInnermostBottomBarStandsAtThePagesFoot() throws {
        let runtime = runtime(node("window", .window, children: [
            node("stack", .navigationStack, children: [
                node("home", .page),
                node("detail", .page, children: [
                    node("content", .vStack, children: [node("bar", .bottomBar, children: [node("own", .text)])]),
                ]),
                node("outer", .bottomBar, children: [node("shared", .text)]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(root.first(id: .manual("detail"))?.chromeBottomBar?.id, .manual("own"))
        XCTAssertEqual(root.first(id: .manual("home"))?.chromeBottomBar?.id, .manual("shared"))
    }

    /// The bar's look a path declares is its nearest arrangement's, one value at a time: a stack further in paints
    /// its own bar. A sidebar wears its own split view's bar and nothing from around it; a sheet wears the look of the
    /// bar over the view presenting it, and its own stack's over that.
    func testTheBarAPathDeclaresIsItsNearest() throws {
        let runtime = runtime(node("window", .window, children: [
            node("outer", .navigationStack, [
                .barBackground: .string("window"), .toolbarStyle: ToolbarStyle.rounded.propValue,
            ], children: [
                node("split", .splitView, [.barForegroundColor: .string("split")], children: [
                    node("menu", .page),
                    node("stack", .navigationStack, [.barBackground: .string("stack")], children: [
                        node("detail", .page, [.title: .string("Detail")], children: [
                            presenting(node("sheet", .page)),
                        ]),
                    ]),
                ]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let chrome = WindowChrome(window: root, arrangement: root.first(id: .manual("outer")))

        XCTAssertEqual(chrome.title, "Detail", "the page still names the window")
        XCTAssertEqual(chrome.background, .string("stack"))
        XCTAssertEqual(chrome.foreground, .string("split"))
        XCTAssertEqual(chrome.toolbarStyle, .rounded, "the buttons' look is the window's page's")

        let menu = try XCTUnwrap(root.first(id: .manual("menu")))
        XCTAssertEqual(menu.barColors.foreground, .string("split"), "the sidebar wears its split view's bar")
        XCTAssertNil(menu.barColors.background, "and nothing from around the split view")
        XCTAssertEqual(menu.toolbarStyle, .system, "nor the buttons' look")

        let sheet = try XCTUnwrap(root.first(id: .manual("sheet")))
        XCTAssertEqual(sheet.barColors.background, .string("stack"), "a sheet wears the presenting view's look")
        XCTAssertEqual(sheet.barColors.foreground, .string("split"))
        XCTAssertEqual(sheet.toolbarStyle, .rounded, "its buttons' look too")
    }

    /// A page says what its bar says of it, and nothing climbs: the chrome shows the line under the title of the page
    /// naming the window, and names the application over a split view's sidebar by the sidebar's page - its title,
    /// else the application's name, its line and its picture. An empty line is none; a window showing no split view
    /// names no application.
    func testAPageSaysItsTitleArea() throws {
        let runtime = runtime(node("window", .window, children: [
            node("split", .splitView, children: [
                node("menu", .page, [.subtitle: .string("Fundamentals"), .icon: .string("mark.png")]),
                node("stack", .navigationStack, children: [
                    node("detail", .page, [.title: .string("Detail"), .subtitle: .string("Buttons")]),
                ]),
            ]),
        ])) { _ in }
        let root = try XCTUnwrap(runtime.tree.root)
        let chrome = WindowChrome(window: root, arrangement: root.first(id: .manual("split")))

        XCTAssertEqual(chrome.title, "Detail")
        XCTAssertEqual(chrome.subtitle, "Buttons", "the line under the title of the page naming the window")
        XCTAssertEqual(chrome.titleArea?.subtitle, "Fundamentals", "the sidebar's page names the application")
        XCTAssertEqual(chrome.titleArea?.icon, HostPicture(.string("mark.png")))
        let menu = try XCTUnwrap(root.first(id: .manual("menu")))
        XCTAssertEqual(
            menu.titleArea(applicationName: "Notes"),
            WindowChrome.TitleArea(title: "Notes", subtitle: "Fundamentals", icon: HostPicture(.string("mark.png"))),
            "a sidebar's page that says no title names the application")

        let bare = self.runtime(node("window", .window, children: [
            node("page", .page, [.title: .string("Page"), .subtitle: .string("")]),
        ])) { _ in }
        let bareRoot = try XCTUnwrap(bare.tree.root)
        let alone = WindowChrome(window: bareRoot, arrangement: bareRoot.first(id: .manual("page")))
        XCTAssertNil(alone.subtitle, "an empty line is none")
        XCTAssertNil(alone.titleArea, "no split view, no application named")
    }

    /// Tabs pushed onto a stack keep the title of the page beneath them; tabs with nothing beneath name the window by
    /// the chosen tab, and a stack in a tab by its top page.
    func testTabsPushedOntoAStackKeepTheTitleBeneathThem() throws {
        let runtime = runtime(node("window", .window, [.title: .string("Window")], children: [
            node("stack", .navigationStack, children: [
                node("group", .page, [.title: .string("Items and Cards")]),
                node("tabs", .tabView, [.selectedTab: .number(1)], children: [
                    node("one", .page, [.title: .string("Example 1")]),
                    node("two", .page, [.title: .string("Example 2")]),
                ]),
            ]),
            node("alone", .tabView, children: [node("tab", .page, [.title: .string("Tab")])]),
            node("stacked", .tabView, children: [
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
                node("tabs", .tabView, [.title: .string("ItemsView")], children: [
                    node("one", .page, [.title: .string("Example 1")]),
                ]),
            ]),
            node("alone", .tabView, [.title: .string("Tabs")], children: [
                node("tab", .page, [.title: .string("Tab")]),
            ]),
            node("stacked", .tabView, [.title: .string("Tabs")], children: [
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
        let runtime = runtime(node("page", .page, children: [node("bar", .menuBar, children: [
            node("file", .menu, [.text: .string("File")], children: [
                node("open", .menuItem, [.text: .string("Open"), .icon: .string("folder")]),
                node("line", .menuSeparator),
                node("erase", .menuItem, [
                    .text: .string("Erase"), .role: ActionRole.destructive.propValue, .icon: .string(""),
                ]),
                node("recent", .menu, [.text: .string("Recent")], children: [
                    node("one", .menuItem, [.text: .string("One"), .isEnabled: .bool(false)]),
                ]),
            ]),
            node("stray", .menuItem),
        ])])) { _ in }

        let menus = try XCTUnwrap(runtime.tree.root).chromeMenus.menus
        XCTAssertEqual(menus.map(\.title), ["File"], "the bar holds only its menus")
        let file = try XCTUnwrap(menus.first).entries
        XCTAssertEqual(file.map(\.kind), [.item, .separator, .item, .submenu])
        XCTAssertEqual(file.map(\.title), ["Open", "", "Erase", "Recent"])
        XCTAssertEqual(file.map(\.icon), [.file("folder"), nil, nil, nil], "an empty picture is none")
        XCTAssertEqual(file.map(\.isDestructive), [false, false, true, false])
        XCTAssertEqual(file.last?.entries.map(\.isEnabled), [false])
    }

    /// A menu bar the path declares, holding `menus`, in `order`.
    private func menuBar(_ id: String, _ menus: [HostPatch], order: Double = 0) -> HostPatch {
        node(id, .menuBar, [.order: .number(order)], children: menus)
    }

    /// A menu captioned `text`.
    private func menu(_ id: String, _ text: String, _ entries: [HostPatch]) -> HostPatch {
        node(id, .menu, [.text: .string(text)], children: entries)
    }

    /// An entry captioned `text`, one that can be chosen unless said otherwise.
    private func menuItem(_ id: String, _ text: String, enabled: Bool = true) -> HostPatch {
        node(id, .menuItem, [.text: .string(text), .isEnabled: .bool(enabled)])
    }

    /// How a composed menu bar reads: each menu's caption and its entries, "!" before one that cannot be chosen and
    /// "-" between sections.
    private func said(_ menus: [MenuEntry]) -> String {
        menus.map { menu in
            let entries = menu.entries.map { $0.kind == .separator ? "-" : ($0.isEnabled ? "" : "!") + $0.title }
            return "\(menu.title)[\(entries.joined(separator: ";"))]"
        }.joined(separator: " ")
    }

    /// An element as a menu's entry: a menu its submenu with its entries, anything else an item with its caption.
    func testAnElementIsAMenusEntryByWhatItIs() throws {
        let runtime = runtime(pathWindow(
            outer: [menuBar("window", [menu("file", "File", [menuItem("new", "New"), menuItem("close", "Close")])])],
            inner: [])) { _ in }
        let file = try XCTUnwrap(runtime.tree.root?.first(id: .manual("file")))
        let new = try XCTUnwrap(runtime.tree.root?.first(id: .manual("new")))

        let submenu = MenuEntry.entry(of: file)
        XCTAssertEqual(submenu.kind, .submenu)
        XCTAssertEqual(submenu.entries.map(\.title), ["New", "Close"])
        XCTAssertEqual(MenuEntry.entry(of: new).kind, .item)
        XCTAssertEqual(MenuEntry.entry(of: new).title, "New")
    }

    /// A menu of an id declared further in joins the one around it as a section after its entries; the others follow
    /// the menus declared around them.
    func testTheMenusOfAPathJoinByIdInSections() throws {
        let runtime = runtime(pathWindow(
            outer: [menuBar("window", [
                menu("file", "File", [menuItem("new", "New"), menuItem("close", "Close")]),
                menu("go", "Go", [menuItem("back", "Back")]),
            ])],
            inner: [menuBar("page", [
                menu("file", "Datei", [menuItem("export", "Export…")]),
                menu("format", "Format", [menuItem("bold", "Bold")]),
            ])])) { _ in }
        let page = try XCTUnwrap(runtime.tree.root?.first(id: .manual("detail")))

        XCTAssertEqual(said(page.chromeMenus.menus), "File[New;Close;-;Export…] Go[Back] Format[Bold]")
        XCTAssertEqual(said(try XCTUnwrap(runtime.tree.root?.first(id: .manual("home"))).chromeMenus.menus),
                       "File[New;Close] Go[Back]", "a page declaring none shows the window's alone")
    }

    /// An entry of an id declared further in stands in the place of the outer one - its words, whether it can be
    /// chosen, its element - and a section left with nothing is none.
    func testAnEntryOfAnIdStandsInThePlaceOfTheOuterOne() throws {
        let runtime = runtime(pathWindow(
            outer: [menuBar("window", [
                menu("file", "File", [menuItem("new", "New"), menuItem("save", "Save", enabled: false)]),
            ])],
            inner: [menuBar("page", [menu("file", "File", [menuItem("save", "Save this page")])])])) { _ in }
        let page = try XCTUnwrap(runtime.tree.root?.first(id: .manual("detail")))

        let menus = page.chromeMenus.menus
        XCTAssertEqual(said(menus), "File[New;Save this page]")
        XCTAssertTrue(menus.first?.entries.last?.element === page.first(id: .manual("save")), "the page's own entry")
    }

    /// A declaration's order moves its menus among the others and its section inside a menu it joins.
    func testADeclarationsOrderMovesItsMenusAndSections() throws {
        let runtime = runtime(pathWindow(
            outer: [menuBar("window", [menu("file", "File", [menuItem("new", "New")])])],
            inner: [menuBar("page", [
                menu("file", "File", [menuItem("open", "Open")]),
                menu("format", "Format", [menuItem("bold", "Bold")]),
            ], order: -1)])) { _ in }
        let page = try XCTUnwrap(runtime.tree.root?.first(id: .manual("detail")))

        XCTAssertEqual(said(page.chromeMenus.menus), "Format[Bold] File[Open;-;New]",
                       "the page's menu before the window's, its section first in the menu it joins")
    }

    /// A menu whose `.id` is a standard menu joins the platform's by that identity, never by its caption.
    func testAStandardMenuIsKnownByItsIdentity() throws {
        let runtime = runtime(node("page", .page, children: [menuBar("bar", [
            menu(StandardMenu.file.description, "Plik", [menuItem("export", "Eksportuj")]),
            menu("file", "File", [menuItem("other", "Other")]),
        ])])) { _ in }

        let menus = try XCTUnwrap(runtime.tree.root).chromeMenus.menus
        XCTAssertEqual(menus.map(\.standard), [.file, nil])
    }

    /// Where a host keeps the Edit menu's own entries, a menu joining `StandardMenu.edit` is headed by them - undoing,
    /// the clipboard and the selection, in the library's words with the field's own keys beside them - and the
    /// application's entries stand after them; another menu is as the path composes it.
    func testAnEditMenuIsHeadedByItsOwnEntriesWhereAHostKeepsThem() throws {
        let runtime = runtime(node("page", .page, children: [menuBar("bar", [
            menu(StandardMenu.edit.description, "Edit", [menuItem("find", "Find")]),
            menu("file", "File", [menuItem("open", "Open")]),
        ])])) { _ in }
        let words = EditWords(
            undo: "Undo", redo: "Redo", cut: "Cut", copy: "Copy", paste: "Paste", delete: "Delete", selectAll: "All")
        let redo = KeyboardShortcut("z", modifiers: [.primary, .shift])

        let menus = try XCTUnwrap(runtime.tree.root).chromeMenus.editing(words, redo: redo).menus

        XCTAssertEqual(said(menus), "Edit[Undo;Redo;-;Cut;Copy;Paste;Delete;-;All;-;Find] File[Open]")
        let own = menus[0].entries.compactMap(\.edit)
        XCTAssertEqual(own, [.undo, .redo, .cut, .copy, .paste, .delete, .selectAll])
        XCTAssertEqual(menus[0].entries.compactMap(\.keyboardShortcut)[0...1], [KeyboardShortcut("z"), redo])
        XCTAssertNil(menus[0].entries.last?.edit, "the application's entry")
        XCTAssertEqual(said(try XCTUnwrap(runtime.tree.root).chromeMenus.menus), "Edit[Find] File[Open]",
                       "a host keeping its own Edit menu composes it alone")
    }

    /// An arrangement's children are its pages: what it declares - its actions, its menus, its title view - is
    /// never its top page, and a search still finds it.
    func testAnArrangementsDeclarationsAreNotItsPages() throws {
        let runtime = runtime(stackWindow([
            node("a", .page), node("b", .page),
            node("items", .toolbarGroup, children: [node("save", .toolbarButton)]),
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
                node("items", .toolbarGroup),
                node("view", .titleView, children: [node("field", .textField)]),
                node("words", .text),
            ])) { _ in }
            let declarer = try XCTUnwrap(runtime.tree.root)

            XCTAssertEqual(declarer.arrangedChildren.map(\.id), [.manual("words")], "\(type)")
        }
    }

    /// Back in a window takes the arrangement's stack where no sheet shows.
    func testTheWayBackTakesTheArrangementsStackWithNoSheet() throws {
        let runtime = runtime(node("window", .window, children: [
            node("main", .navigationStack, children: [node("main.a", .page), node("main.b", .page)]),
        ])) { _ in }
        let presentation = WindowPresentation()
        _ = presentation.show(try XCTUnwrap(runtime.tree.root), in: runtime.lifecycle)

        guard case .pop(let main) = presentation.wayBack else { return XCTFail("the arrangement's stack") }
        XCTAssertEqual(main.id, .manual("main"))
    }

    /// A button presenting `page` in its sheet.
    private func presenting(_ page: HostPatch, as id: String = "presenter") -> HostPatch {
        node(id, .button, children: [node("\(id).sheet", .sheet, [.isPresented: .bool(true)], children: [page])])
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
        guard element.type == .tabView, case .manual(let id) = element.id else { return }
        read(id, element.tabsStandInWindow)
    }

    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func presentFrame(_ changed: Set<Prop>) {}
    func arrangeChildren() {}
    func invalidateMeasurements() {}
    func configureLayoutMotion() {}
    func leave() {}
}

/// A page whose text's context menu holds a setting's entry that also counts its turns.
private struct CheckedApplication: Application {
    var body: some Scene { WindowGroup { CheckedPage() } }
}

private struct CheckedPage: View {
    @State private var bold = false
    @State private var turns = 0

    var body: some View {
        Text("turns \(turns), bold \(bold)").contextMenu {
            MenuToggle("Bold", isOn: $bold).onToggled { _ in turns += 1 }
        }
    }
}

/// An application whose stack shows two pages over its root.
private struct PoppedPathApplication: Application {
    var body: some Scene {
        WindowGroup { PoppedPathPage() }
    }
}

private struct PoppedPathPage: View {
    @State private var path = [1, 2]

    var body: some View {
        NavigationStack($path) { Text("Root") } destination: { number in Text("Page \(number)") }
    }
}

/// What the pages of `PhaseLogApplication` heard, in turn.
@MainActor
private enum PhaseLog {
    static var said: [String] = []
    static let path = State(wrappedValue: [1])
}

private struct PhaseLogApplication: Application {
    var body: some Scene {
        WindowGroup { PhaseLogPage() }
    }
}

private struct PhaseLogPage: View {
    var body: some View {
        NavigationStack(PhaseLog.path.projectedValue) {
            Text("Root").onAppearing { PhaseLog.said.append("Root appearing") }
        } destination: { _ in
            Text("Pushed")
                .onAppearing { PhaseLog.said.append("Pushed appearing") }
                .onDisappearing { PhaseLog.said.append("Pushed disappearing") }
                .onDestroying { PhaseLog.said.append("Pushed destroying") }
        }
    }
}
