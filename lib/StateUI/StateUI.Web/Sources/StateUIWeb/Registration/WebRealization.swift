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
        .complete(BottomBarContract.scrollEdge),
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
        .partial(BarElementContract.barBackground,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .complete(BarElementContract.barScrollEdge),
        .complete(BarElementContract.toolbarStyle),
        .complete(BarElementContract.barForegroundColor),
        .complete(MenuBarContract.order),
        .complete(EnabledElementContract.isEnabled, on: MenuContract.self),
        .complete(TextElementContract.text, on: MenuContract.self),
        .complete(ToggleElementContract.isOn, on: MenuToggleContract.self),
        .complete(ToggleElementContract.toggled, on: MenuToggleContract.self),
        .complete(ClickElementContract.clicked, on: ActionElementContract.self),
        .complete(IconElementContract.icon, on: MenuItemContract.self),
        .complete(IconElementContract.icon, on: MenuToggleContract.self),
        .complete(IconElementContract.icon, on: ToolbarButtonContract.self),
        .complete(IconElementContract.icon, on: ToolbarToggleContract.self),
        .complete(ActionElementContract.role),
        .complete(EnabledElementContract.isEnabled, on: MenuItemContract.self),
        .complete(EnabledElementContract.isEnabled, on: MenuToggleContract.self),
        .complete(EnabledElementContract.isEnabled, on: ToolbarButtonContract.self),
        .complete(EnabledElementContract.isEnabled, on: ToolbarToggleContract.self),
        .complete(ShortcutElementContract.keyboardShortcut, on: MenuItemContract.self),
        .complete(ShortcutElementContract.keyboardShortcut, on: MenuToggleContract.self),
        .complete(ShortcutElementContract.keyboardShortcut, on: ToolbarButtonContract.self),
        .complete(ShortcutElementContract.keyboardShortcut, on: ToolbarToggleContract.self),
        .complete(TextElementContract.text, on: MenuItemContract.self),
        .complete(TextElementContract.text, on: MenuToggleContract.self),
        .complete(TextElementContract.text, on: ToolbarButtonContract.self),
        .complete(TextElementContract.text, on: ToolbarToggleContract.self),
        .complete(IconElementContract.icon, on: PageElementContract.self),
        .complete(PageElementContract.title),
        .complete(StyledElementContract.style, on: VisualElementContract.self),
        .partial(FilledShapeContract.fill, missing: "A page has no glass: a figure of glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(BackgroundElementContract.background, on: VisualElementContract.self,
            missing: "A brush fills the view with its first color alone; a blur and glass are drawn by a layout, and elsewhere a blur's color stands in."),

        // MARK: Entries - a control's or a part's own
        .complete(ButtonMenuElementContract.menuKind, on: ButtonContract.self),
        .complete(ButtonMenuElementContract.menuKind, on: ToolbarButtonContract.self),
        .complete(ButtonMenuElementContract.showsMenuArrow, on: ButtonContract.self),
        .complete(TextAndIconElementContract.showsText, on: ButtonContract.self),
        .complete(ButtonMenuElementContract.showsMenuArrow, on: ToolbarButtonContract.self),
        .complete(PresentedElementContract.isPresented, on: SheetContract.self),
        .complete(PresentedElementContract.isPresentedChanged, on: SheetContract.self),
        .complete(NavigationStackContract.popped),
        .complete(PageContract.appearing),
        .complete(PageContract.backButtonTitle),
        .complete(BackgroundElementContract.background, on: PageElementContract.self),
        .complete(PageElementContract.linkOpened),
        .complete(PageContract.disappearing),
        .complete(PageContract.navigatedFrom),
        .complete(PageContract.navigatedTo),
        .complete(PageContract.navigatingFrom),
        .complete(PageContract.showsBackButton),
        .complete(PageContract.showsCloseButton),
        .complete(PageContract.showsNavigationBar),
        .complete(PageContract.showsTitle),
        .complete(PageContract.subtitle),
        .complete(PresentedElementContract.isPresented, on: PopoverContract.self),
        .complete(PresentedElementContract.isPresentedChanged, on: PopoverContract.self),
        .complete(SplitViewContract.showsSidebar),
        .complete(SplitViewContract.showsSidebarChanged),
        .complete(SplitViewContract.showsSidebarToggle),
        .partial(SplitViewContract.sidebarBackground,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(SplitViewContract.sidebarOverlayBackground,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .complete(SplitViewContract.sidebarOverlays),
        .notPlanned(BackgroundElementContract.background, on: SliderContract.self,
            reason: "The browser draws its slider over the whole box and paints no "
            + "background under it."),
        .complete(TabViewContract.selectedTab),
        .complete(TabViewContract.selectedTabChanged),
        .complete(BackgroundElementContract.background, on: TextSpanContract.self),
        .complete(PickerContract.presentation),
        .complete(FontElementContract.fontAttributes, on: TextSpanContract.self),
        .complete(FontElementContract.fontWeight, on: TextSpanContract.self),
        .complete(FontElementContract.textStyle, on: TextSpanContract.self),
        .complete(FontElementContract.fontFamily, on: TextSpanContract.self),
        .complete(FontElementContract.fontSize, on: TextSpanContract.self),
        .complete(FontElementContract.isFontAutoScalingEnabled, on: TextSpanContract.self),
        .complete(TextElementContract.text, on: TextSpanContract.self),
        .complete(TextualElementContract.textCase, on: TextSpanContract.self),
        .complete(TextColorElementContract.textColor, on: TextSpanContract.self),
        .complete(DecorableTextElementContract.textDecorations, on: TextSpanContract.self),
        .complete(TrackingElementContract.tracking, on: TextSpanContract.self),
        .complete(TextAndIconElementContract.showsText, on: ToolbarButtonContract.self),
        .complete(ToggleElementContract.isOn, on: ToolbarToggleContract.self),
        .complete(ToolbarToggleContract.onIcon),
        .complete(TextAndIconElementContract.showsText, on: ToolbarToggleContract.self),
        .complete(ToggleElementContract.toggled, on: ToolbarToggleContract.self),
        .complete(ViewContract.layoutBody),
        .complete(IconElementContract.icon, on: ToolbarLabelContract.self),
        .complete(TextElementContract.text, on: ToolbarLabelContract.self),
        .complete(ToolbarGroupContract.barEdge),
        .complete(ToolbarGroupContract.order),
        .complete(ToolbarGroupContract.part),
        .complete(ToolbarGroupContract.hidesWithSidebar),
        .complete(EnabledElementContract.isEnabled, on: ToolbarGroupContract.self),
        .complete(ToolbarGroupContract.position),
        .notPlanned(ToolbarGroupContract.standsAlone,
            reason: "The bar draws every group on a glass of its own, a lone item's too."),
        .complete(SessionElementContract.activated, on: SceneContract.self),
        .complete(SessionElementContract.deactivated, on: SceneContract.self),
        .complete(SessionElementContract.stopped, on: SceneContract.self),
        .notPlanned(SceneContract.windowClosed,
            reason: "A page's one window closes with its tab, which hears nothing after."),
        .notPlanned(WindowContract.windowKind, reason: "A page is one window: it opens none of a kind."),
        .notPlanned(WindowContract.windowValue, reason: "A page is one window: it opens none for a value."),
        .complete(SessionElementContract.activated, on: WindowContract.self),
        .complete(WindowContract.created),
        .complete(SessionElementContract.deactivated, on: WindowContract.self),
        .complete(WindowContract.destroying),
        .complete(SessionElementContract.stopped, on: WindowContract.self),
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
        .partial(BackgroundElementContract.background, on: GridContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(BackgroundElementContract.background, on: HStackContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(BackgroundElementContract.background, on: VStackContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(BackgroundElementContract.background, on: ZStackContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(BackgroundElementContract.background, on: FillContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(BackgroundElementContract.background, on: SpaceContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .partial(BackgroundElementContract.background, on: MotionLayoutContract.self,
            missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color."),
        .complete(MotionLayoutContract.translationOrientation),
        .complete(LayoutContract.ignoresSafeArea),
        .complete(MotionLayoutContract.translationUpdated),
        .complete(MotionLayoutContract.wheelStepped),
        .complete(MotionLayoutContract.itemDrag),
        .complete(MotionLayoutContract.itemDragUpdated),
        .complete(MotionLayoutContract.magnifies),
        .complete(MotionLayoutContract.pans),
        .partial(MotionLayoutContract.rotates,
            missing: "Chrome and Firefox tell no trackpad's rotation: two fingers turn "
            + "a layout on a touch screen, and on a trackpad in Safari."),
        .complete(MotionLayoutContract.pinchRotationUpdated),
        .partial(BackgroundElementContract.background, on: WindowContract.self,
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
        .partial(ApplicationContract.sendRequest,
            missing: "A page's fetch refuses the methods CONNECT, TRACE and TRACK: a request with one fails with that reason."),
        .notPlanned(ColorPickerContract.choosesOpacity,
            reason: "The browser's color input chooses no opacity: every color it gives is opaque."),
    ] + pickerOpening + dayFields + HostRecord.motionLayout + BarItemLook.realized

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
        let pressed = "The browser's select opens its list at the user's press, and the list keeps the pointer until "
            + "it closes: the page hears no hold, drag or swipe of it, and its release only where it was pressed."
        let pressing: [any ContractMember] = [
            ViewContract.tapped, ViewContract.held, ViewContract.holdDuration, ViewContract.panUpdated,
            ViewContract.panTouchCount, ViewContract.panXChannel, ViewContract.panYChannel, ViewContract.swiped,
            ViewContract.swipeDirections, ViewContract.swipeThreshold, ViewContract.pointerReleased,
        ]
        return pressing.map { .notPlanned($0, on: PickerContract.self, reason: pressed) } + [
        ] + ([DatePickerContract.self, PickerContract.self, TimePickerContract.self] as [any Contract.Type]).flatMap {
            picker -> [HostRecord] in [
            .notPlanned(PopupElementContract.isOpen, on: picker, reason: opens),
            .notPlanned(PopupElementContract.opened, on: picker, reason: opened),
            .notPlanned(PopupElementContract.closed, on: picker, reason: closed),
        ] }
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
