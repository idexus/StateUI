// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry - the library's elements it makes none of, which it shows by name as
/// unsupported - and, member by member, what its records say: the Web column of the control dictionary.
/// Design: docs/design/contracts/dictionary.md#marks
enum WebRealization {
    /// The elements the host makes itself, outside the registry: the pages, the arrangements they stand in, what a
    /// window lays over them, and a view's popover.
    static let madeByHost: Set<NodeType> = [.page, .navigationStack, .splitView, .tabView, .overlay, .popover]

    /// The entries this host leaves to the application, which registers its own control for each: the browser has
    /// no map of its own, and a map needs a provider and its key.
    static let byApplication: [any ElementContract.Type] = [MapContract.self, MarkerContract.self]

    /// What the host's own records say, member by member, before what its registry says: what it realizes through
    /// the host layer's pages and chrome, outside the registry, and what a page never asks of the browser's window.
    /// Why no element is pulled to refresh here.
    private static let noPull = "The DOM offers no pull to refresh of a part of a page - a browser's own pull "
        + "reloads the whole page: a page refreshes by a command."

    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .notPlanned(RefreshElementContract.isRefreshEnabled, reason: Self.noPull),
        .notPlanned(RefreshElementContract.isRefreshing, reason: Self.noPull),
        .notPlanned(RefreshElementContract.refreshRequested, reason: Self.noPull),
        .notPlanned(VisualElementContract.accessibilityActionPerformed,
            reason: "ARIA offers no action of an application's own words."),
        .notPlanned(VisualElementContract.accessibilityActions,
            reason: "ARIA offers no action of an application's own words."),
        .notPlanned(VisualElementContract.accessibilityAdjusted,
            reason: "A browser's screen reader steps a slider by the keys it sends the page, not by a step of its own."),
        .complete(BarElementContract.barBackgroundColor),
        .complete(BarElementContract.barButtonBackgroundColor),
        .complete(BarElementContract.toolbarStyle),
        .complete(BarElementContract.barForegroundColor),
        .notPlanned(BarElementContract.barIcon,
            reason: "A page's bar names its page and the application, and no mark: the browser's tab shows the site's icon."),
        .complete(BarElementContract.barSubtitle),
        .complete(BarElementContract.barTitle),
        .complete(MenuBarContract.order),
        .complete(MenuContract.isEnabled),
        .complete(MenuContract.text),
        .complete(MenuItemContract.isOn),
        .complete(MenuItemContract.toggled),
        .complete(MenuItemElementContract.clicked),
        .complete(MenuItemElementContract.icon),
        .complete(MenuItemElementContract.role),
        .complete(MenuItemElementContract.isEnabled),
        .complete(MenuItemElementContract.keyboardShortcut),
        .complete(MenuItemElementContract.text),
        .complete(PageElementContract.icon),
        .complete(PageElementContract.title),
        .complete(VisualElementContract.style),
        .partial(VisualElementContract.background,
            missing: "A brush fills the view with its first color alone; a blur and glass are drawn by a layout, and elsewhere a blur's color stands in."),
        .unrealized(VisualElementContract.style, on: ItemsViewContract.self,
            why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),

        // MARK: Entries - a control's or a part's own
        .complete(ButtonContract.menuKind),
        .complete(ButtonContract.showsMenuArrow),
        .complete(ModalStackContract.popped),
        .complete(NavigationStackContract.popped),
        .complete(PageContract.appearing),
        .complete(PageContract.backButtonTitle),
        .complete(PageContract.background),
        .complete(PageContract.disappearing),
        .complete(PageContract.navigatedFrom),
        .complete(PageContract.navigatedTo),
        .complete(PageContract.navigatingFrom),
        .complete(PageContract.showsBackButton),
        .complete(PageContract.showsNavigationBar),
        .complete(PageContract.showsTitle),
        .complete(PopoverContract.isShown),
        .complete(PopoverContract.isShownChanged),
        .complete(SplitViewContract.showsSidebar),
        .complete(SplitViewContract.showsSidebarChanged),
        .partial(SplitViewContract.sidebarBackground,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(SplitViewContract.flyoutBackground,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .complete(SplitViewContract.sidebarOverlays),
        .notPlanned(VisualElementContract.background, on: SliderContract.self,
            reason: "The browser draws its slider over the whole box and paints no "
            + "background under it."),
        .complete(TabViewContract.selectedTab),
        .complete(TabViewContract.selectedTabChanged),
        .complete(TextSpanContract.background),
        .complete(PickerContract.presentation),
        .complete(FontElementContract.fontAttributes, on: TextSpanContract.self),
        .complete(FontElementContract.fontWeight, on: TextSpanContract.self),
        .complete(FontElementContract.textStyle, on: TextSpanContract.self),
        .complete(FontElementContract.fontFamily, on: TextSpanContract.self),
        .complete(FontElementContract.fontSize, on: TextSpanContract.self),
        .complete(FontElementContract.isFontAutoScalingEnabled, on: TextSpanContract.self),
        .complete(TextualElementContract.text, on: TextSpanContract.self),
        .complete(TextualElementContract.textCase, on: TextSpanContract.self),
        .complete(TextColorElementContract.textColor, on: TextSpanContract.self),
        .complete(DecorableTextElementContract.textDecorations, on: TextSpanContract.self),
        .complete(TrackingElementContract.tracking, on: TextSpanContract.self),
        .complete(ToolbarItemContract.placement),
        .complete(ToolbarItemContract.showsText),
        .complete(ToolbarItemGroupContract.order),
        .complete(ToolbarItemGroupContract.side),
        .complete(SceneContract.activated),
        .complete(SceneContract.deactivated),
        .complete(SceneContract.stopped),
        .notPlanned(SceneContract.windowClosed,
            reason: "A page's one window closes with its tab, which hears nothing after."),
        .notPlanned(WindowContract.windowType, reason: "A page is one window: it opens none of a kind."),
        .notPlanned(WindowContract.windowValue, reason: "A page is one window: it opens none for a value."),
        .complete(WindowContract.activated),
        .complete(WindowContract.created),
        .complete(WindowContract.deactivated),
        .complete(WindowContract.destroying),
        .complete(WindowContract.resumed),
        .complete(WindowContract.stopped),
        .notPlanned(WindowContract.floatsOnTop,
            reason: "A page keeps no browser window above the others: the system stacks them."),
        .notPlanned(WindowContract.height,
            reason: "A page sizes no browser window: the user does, and the page fills it."),
        .notPlanned(WindowContract.hidesWhenInactive,
            reason: "The browser shows a page whenever its tab shows, whichever application the user is in."),
        .notPlanned(WindowContract.isMaximizable,
            reason: "A page asks nothing of how the browser's window is resized."),
        .notPlanned(WindowContract.isMinimizable,
            reason: "A page asks nothing of how the browser's window is put away."),
        .partial(VisualElementContract.background, on: GridContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(VisualElementContract.background, on: HStackContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(VisualElementContract.background, on: VStackContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(VisualElementContract.background, on: ZStackContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(VisualElementContract.background, on: LayoutEngineContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .complete(LayoutEngineContract.handAxis),
        .complete(LayoutEngineContract.handMoved),
        .complete(LayoutEngineContract.handStepped),
        .complete(LayoutEngineContract.itemDrag),
        .complete(LayoutEngineContract.itemMoved),
        .complete(LayoutEngineContract.magnifies),
        .complete(LayoutEngineContract.pans),
        .partial(LayoutEngineContract.rotates,
            missing: "Chrome and Firefox tell no trackpad's rotation: two fingers turn "
            + "a layout on a touch screen, and on a trackpad in Safari."),
        .complete(LayoutEngineContract.pinchMoved),
        .partial(WindowContract.background,
            missing: "A page draws its window opaque: a blur or glass shows its color."),
        .notPlanned(WindowContract.maximumHeight, reason: "A page bounds no browser window: the user sizes it."),
        .notPlanned(WindowContract.maximumWidth, reason: "A page bounds no browser window: the user sizes it."),
        .notPlanned(WindowContract.minimumHeight, reason: "A page bounds no browser window: the user sizes it."),
        .notPlanned(WindowContract.minimumWidth, reason: "A page bounds no browser window: the user sizes it."),
        .complete(WindowContract.title),
        .notPlanned(WindowContract.width,
            reason: "A page sizes no browser window: the user does, and the page fills it."),
        .notPlanned(WindowContract.x, reason: "A page places no browser window: the system does."),
        .notPlanned(WindowContract.y, reason: "A page places no browser window: the system does."),
    ] + pickerOpening + dayFields + HostRecord.layoutEngine

    /// A day's and a time's field: left to right, whatever the direction around them.
    private static let dayFields: [HostRecord] = ([DatePickerContract.self, TimePickerContract.self] as [any ElementContract.Type]).map {
        picker -> HostRecord in
        .notPlanned(VisualElementContract.layoutDirection, on: picker, reason: "The browser lays a day's and a time's "
            + "field out left to right in every direction, over any the page gives it.")
    }

    /// A picker's list, a day's calendar and a time's clock: the browser's own, opened at the user's press.
    private static let pickerOpening: [HostRecord] = {
        let opens = "The browser opens a picker's list or calendar only at the user's press, and closes it at the "
            + "user's hand alone."
        let opened = "The browser says nothing as a picker's list or calendar opens."
        let closed = "The browser says nothing as a picker's list or calendar closes."
        return [
            .notPlanned(DatePickerContract.isOpen, reason: opens), .notPlanned(DatePickerContract.opened, reason: opened),
            .notPlanned(DatePickerContract.closed, reason: closed), .notPlanned(PickerContract.isOpen, reason: opens),
            .notPlanned(PickerContract.opened, reason: opened), .notPlanned(PickerContract.closed, reason: closed),
            .notPlanned(TimePickerContract.isOpen, reason: opens), .notPlanned(TimePickerContract.opened, reason: opened),
            .notPlanned(TimePickerContract.closed, reason: closed),
        ]
    }()

    /// The acts this host performs: every host's (`HostActs.performed`), the files (`HostActs.files`), the requests
    /// (`HostActs.network`), a list scrolled to an item, and a web view's steps and scripts.
    static let acts: [any ContractMember] = HostActs.performed + HostActs.files + HostActs.network + [
        ItemsViewContract.scrollTo, WebViewContract.goBack, WebViewContract.goForward, WebViewContract.reload,
        WebViewContract.evaluateJavaScript,
    ]

    /// The library's elements this host makes none of: neither its registry nor itself, and none it shows with no
    /// view.
    @MainActor static var unmade: [any ElementContract.Type] {
        let made = WebRegistrations.registry.realization.elements.union(NodeType.viewlessTypes).union(madeByHost)
        return LibraryContracts.elements.filter { !made.contains($0.nodeType) }
    }

    /// What the Web realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        let registry = WebRegistrations.registry
        return HostRegister(
            records: records,
            unrealized: unmade.filter { element in !byApplication.contains { $0.nodeType == element.nodeType } },
            byApplication: byApplication
        ).and(HostDeclaration(realization: registry.realization, shared: registry.sharedNames, acts: acts.map(\.name)))
    }
}
