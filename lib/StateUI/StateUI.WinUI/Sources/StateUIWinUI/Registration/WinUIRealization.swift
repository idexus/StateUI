// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the WinUI 3 column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum WinUIRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: [any ElementContract.Type] = []

    /// The entries this host leaves to the application, which registers its own control for each: the platform has
    /// no map of its own, and a map needs a provider and its key.
    static let byApplication: [any ElementContract.Type] = [MapContract.self, MarkerContract.self]

    /// The entries a backend realizes on this host - a package of its own, for a library WinUI does not ship - which
    /// the application's head registers: WebView2's web view. Realized none of until it is registered.
    static let backends: [any ElementContract.Type] = [WebViewContract.self]

    /// What the running host realizes none of: what it never makes, what it leaves to the application, and each
    /// backend no one registered.
    @MainActor static var unmade: [any ElementContract.Type] {
        unrealized + byApplication + unregistered
    }

    /// Each backend no one registered: realized none of until it is.
    @MainActor static var unregistered: [any ElementContract.Type] {
        backends.filter { !WinUIRegistrations.registry.realization.elements.contains($0.nodeType) }
    }

    /// The entries Windows will not have; none.
    static let notPlanned: [(any ElementContract.Type, reason: String)] = []

    /// Every record, the tiers' first.
    /// Why a list is not pulled to refresh here.
    private static let noListPull = "WinUI's RefreshContainer pulls a ScrollViewer, and an ItemsView scrolls in a "
        + "ScrollView it does not pull."

    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .notPlanned(ApplicationContract.useAccentColor,
            reason: "The user's accent stands on Windows: StateUI does not override it with the application's."),
        .notPlanned(RefreshElementContract.isRefreshEnabled, on: ItemsViewContract.self, reason: Self.noListPull),
        .notPlanned(RefreshElementContract.isRefreshing, on: ItemsViewContract.self, reason: Self.noListPull),
        .notPlanned(RefreshElementContract.refreshRequested, on: ItemsViewContract.self, reason: Self.noListPull),
        .notPlanned(LayoutContract.ignoresSafeArea, reason: "A Windows desktop window keeps no area of its content "
            + "clear: nothing of the window stands over its content."),
        .notPlanned(VisualElementContract.accessibilityActionPerformed,
            reason: "UI Automation offers no action of an application's own words."),
        .notPlanned(VisualElementContract.accessibilityActions,
            reason: "UI Automation offers no action of an application's own words."),
        .notPlanned(VisualElementContract.accessibilityAdjusted,
            reason: "UI Automation steps a range by its numbers, which a view made of parts does not say."),
        .notPlanned(VisualElementContract.accessibilityRole,
            reason: "A WinUI control is its own kind to assistive technology; a stack or a grid StateUI draws says another."),
        .notPlanned(VisualElementContract.accessibilityValue,
            reason: "A WinUI control says its own value to assistive technology; a stack or a grid StateUI draws says another."),
        .partial(FilledShapeContract.fill, missing: "A figure's acrylic is not drawn yet: a blur or glass shows the theme's color standing in, its tint over it."),
        .partial(ViewContract.held, missing: "WinUI tells a hold of a finger or a pen: a mouse button held is no hold."),
        .notPlanned(ViewContract.holdDuration,
            reason: "WinUI's hold comes after the system's own time: a view keeps no time of its own."),
        .partial(VisualElementContract.background,
            missing: "An element's acrylic is not drawn yet: a blur or glass shows the theme's color standing in, its tint over it."),
        .partial(BarElementContract.barBackground,
            missing: "WinUI has no glass: a bar of glass shows the in-app acrylic at its fallback thickness."),
        .notPlanned(BarElementContract.barButtonBackgroundColor, reason: "An app bar button is WinUI's own, with no background of the application's."),
        .notPlanned(BarElementContract.toolbarStyle, reason: "The bar's buttons keep WinUI's own look."),
        .complete(BarElementContract.barForegroundColor),
        .complete(MenuToggleContract.isOn),
        .complete(MenuToggleContract.toggled),
        .complete(ActionElementContract.clicked),
        .complete(MenuItemElementContract.icon),
        .complete(ActionElementContract.role),
        .complete(MenuItemElementContract.isEnabled),
        .complete(MenuItemElementContract.keyboardShortcut),
        .complete(ButtonMenuElementContract.menuKind, on: ButtonContract.self),
        .partial(ButtonMenuElementContract.menuKind, on: ToolbarButtonContract.self,
            missing: "A WinUI command bar's button has no arrow part: a split one opens its menu held."),
        .complete(ButtonMenuElementContract.showsMenuArrow, on: ButtonContract.self),
        .complete(TextAndIconElementContract.showsText, on: ButtonContract.self),
        .notPlanned(ButtonMenuElementContract.showsMenuArrow, on: ToolbarButtonContract.self,
            reason: "A WinUI command bar's button shows no arrow: its flyout opens from its click."),
        .complete(ButtonContract.role),
        .complete(MenuItemElementContract.text),
        .complete(PageElementContract.icon),
        .complete(PageElementContract.title),
        .complete(VisualElementContract.ignoresInput),
        .complete(VisualElementContract.layoutDirection),
        .complete(VisualElementContract.style),

        // MARK: Entries - a control's or a part's own
        .notPlanned(PageContract.backButtonTitle, reason: "WinUI's way back is an arrow, with no words."),
        .notPlanned(TextInputContract.cursorPosition, on: SearchFieldContract.self, reason: searchCaret),
        .notPlanned(TextInputContract.selectionLength, on: SearchFieldContract.self, reason: searchCaret),
        .complete(VisualElementContract.accessibilityRole, on: VStackContract.self),
        .complete(VisualElementContract.accessibilityRole, on: HStackContract.self),
        .complete(VisualElementContract.accessibilityRole, on: ZStackContract.self),
        .complete(VisualElementContract.accessibilityRole, on: FillContract.self),
        .complete(VisualElementContract.accessibilityRole, on: SpaceContract.self),
        .complete(VisualElementContract.accessibilityRole, on: GridContract.self),
        .complete(VisualElementContract.accessibilityValue, on: VStackContract.self),
        .complete(VisualElementContract.accessibilityValue, on: HStackContract.self),
        .complete(VisualElementContract.accessibilityValue, on: ZStackContract.self),
        .complete(VisualElementContract.accessibilityValue, on: FillContract.self),
        .complete(VisualElementContract.accessibilityValue, on: SpaceContract.self),
        .complete(VisualElementContract.accessibilityValue, on: GridContract.self),
        .partial(TextInputContract.inputPurpose,
            missing: "Filling in: WinUI's text box keeps no saved names, passwords or codes to fill it in from; a "
            + "name, a password and a code get their keys and checking all the same."),
        .partial(SearchFieldContract.submitLabel,
            missing: "The return key's word: WinUI gives a text box no word for the return key of the keyboard on the screen; Next "
            + "hands the keyboard on all the same."),
        .partial(TextFieldContract.submitLabel,
            missing: "The return key's word: WinUI gives a text box no word for the return key of the keyboard on the screen; Next "
            + "hands the keyboard on all the same."),
        .notPlanned(VisualElementContract.background, on: SpinnerContract.self,
            reason: "WinUI's progress ring paints its Background as its "
            + "track, no ground under its frame."),
        .partial(VisualElementContract.background, on: CanvasContract.self,
            missing: "A brush fills the canvas with its first color alone."),
        .partial(VisualElementContract.hidesChildrenFromAccessibility, on: SpinnerContract.self,
            missing: Self.partsStayMet),
        .partial(VisualElementContract.hidesChildrenFromAccessibility, on: DatePickerContract.self,
            missing: Self.partsStayMet),
        .partial(VisualElementContract.hidesChildrenFromAccessibility, on: SearchFieldContract.self,
            missing: Self.partsStayMet),
        .partial(VisualElementContract.hidesChildrenFromAccessibility, on: StepperContract.self,
            missing: Self.partsStayMet),
        .partial(VisualElementContract.hidesChildrenFromAccessibility, on: TimePickerContract.self,
            missing: Self.partsStayMet),
        .notPlanned(VisualElementContract.background, on: CapsuleContract.self, reason: figurePaintsNoGround),
        .notPlanned(VisualElementContract.background, on: EllipseContract.self, reason: figurePaintsNoGround),
        .notPlanned(VisualElementContract.background, on: ImageContract.self,
            reason: "WinUI's picture paints the picture alone, no ground around it."),
        .notPlanned(VisualElementContract.background, on: LineContract.self, reason: figurePaintsNoGround),
        .notPlanned(VisualElementContract.background, on: PathContract.self, reason: figurePaintsNoGround),
        .notPlanned(VisualElementContract.background, on: PolygonContract.self, reason: figurePaintsNoGround),
        .notPlanned(VisualElementContract.background, on: PolylineContract.self, reason: figurePaintsNoGround),
        .notPlanned(VisualElementContract.background, on: ProgressBarContract.self,
            reason: "WinUI's progress bar paints its Background as its track, no "
            + "ground under its frame."),
        .notPlanned(VisualElementContract.background, on: RectangleContract.self, reason: figurePaintsNoGround),
        .unrealized(VisualElementContract.background, on: WebViewContract.self,
            why: "WebView2 is no control and takes no Background: what shows "
            + "where its page paints nothing is its DefaultBackgroundColor, which the backend does not set yet."),
        .unrealized(VisualElementContract.ignoresInput, on: SpinnerContract.self, why: hitOnlyWherePainted),
        .partial(DatePickerContract.format,
            missing: "WinUI writes the long and the short day in the user's own way, and the medium as the short."),
        .unrealized(VisualElementContract.style, on: ItemsViewContract.self,
            why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .complete(LayoutEngineContract.handAxis),
        .complete(LayoutEngineContract.handMoved),
        .notPlanned(LayoutEngineContract.handStepped,
            reason: "A wheel reaches the layout as WinUI's own scroller takes it, "
            + "its tracker's: a notch goes as far as the platform scrolls for it, and the tracker tells no notch."),
        .complete(LayoutEngineContract.itemDrag),
        .complete(LayoutEngineContract.itemMoved),
        .complete(LayoutEngineContract.magnifies),
        .complete(LayoutEngineContract.pans),
        .complete(LayoutEngineContract.rotates),
        .complete(LayoutEngineContract.pinchMoved),
        .complete(MenuContract.isEnabled),
        .complete(MenuContract.text),
        .complete(MenuBarContract.order),
        .complete(SheetContract.isPresented),
        .complete(SheetContract.isPresentedChanged),
        .complete(NavigationStackContract.popped),
        .complete(PageContract.appearing),
        .complete(PageElementContract.background),
        .complete(PageElementContract.linkOpened),
        .complete(PageContract.disappearing),
        .complete(PageContract.showsBackButton),
        .complete(PageContract.showsCloseButton),
        .complete(PageContract.showsNavigationBar),
        .complete(PageContract.showsTitle),
        .complete(PageContract.subtitle),
        .complete(PopoverContract.isPresented),
        .complete(PopoverContract.isPresentedChanged),
        .complete(PageContract.navigatedFrom),
        .complete(PageContract.navigatedTo),
        .complete(PageContract.navigatingFrom),
        .partial(TextAlignmentElementContract.horizontalTextAlignment, on: SearchFieldContract.self,
            missing: "The placeholder stands at the start: "
            + "AutoSuggestBox's text box template aligns only the words typed."),
        .complete(SceneContract.activated),
        .complete(SceneContract.deactivated),
        .complete(SceneContract.stopped),
        .complete(SceneContract.windowClosed),
        .complete(TextSpanContract.background),
        .complete(TrackingElementContract.tracking, on: TextSpanContract.self),
        .complete(PickerContract.presentation),
        .complete(FontElementContract.fontAttributes, on: TextSpanContract.self),
        .complete(FontElementContract.fontWeight, on: TextSpanContract.self),
        .complete(FontElementContract.textStyle, on: TextSpanContract.self),
        .complete(FontElementContract.fontFamily, on: TextSpanContract.self),
        .complete(FontElementContract.fontSize, on: TextSpanContract.self),
        .notPlanned(FontElementContract.isFontAutoScalingEnabled, on: TextSpanContract.self,
            reason: "WinUI scales a text's runs with the text: a run has no text scaling of its own."),
        .complete(TextualElementContract.text, on: TextSpanContract.self),
        .complete(TextualElementContract.textCase, on: TextSpanContract.self),
        .complete(TextColorElementContract.textColor, on: TextSpanContract.self),
        .complete(DecorableTextElementContract.textDecorations, on: TextSpanContract.self),
        .complete(SplitViewContract.showsSidebar),
        .complete(SplitViewContract.showsSidebarChanged),
        .complete(SplitViewContract.showsSidebarToggle),
        .partial(SplitViewContract.sidebarBackground, missing: Self.paneHasNoGlass),
        .partial(SplitViewContract.sidebarOverlayBackground, missing: Self.paneHasNoGlass),
        .complete(SplitViewContract.sidebarOverlays),
        .complete(TabViewContract.selectedTab),
        .complete(TabViewContract.selectedTabChanged),
        .partial(TextFieldContract.isPassword, missing: "A PasswordBox has no read-only state, alignment, case, caret "
            + "or selection: a password field keeps none of these."),
        .partial(TimePickerContract.format,
            missing: "WinUI's time picker writes hours and minutes as the user's clock does, whatever the format asks: no seconds, no pattern."),
        .complete(ToolbarGroupContract.order),
        .complete(ToolbarGroupContract.part),
        .complete(ToolbarGroupContract.hidesWithSidebar),
        .complete(ToolbarGroupContract.isEnabled),
        .complete(ToolbarGroupContract.position),
        .complete(TextAndIconElementContract.showsText, on: ToolbarButtonContract.self),
        .complete(ToolbarToggleContract.isOn),
        .complete(ToolbarToggleContract.onIcon),
        .complete(TextAndIconElementContract.showsText, on: ToolbarToggleContract.self),
        .complete(ToolbarToggleContract.toggled),
        .notPlanned(VisualElementContract.isEnabled, on: WebViewContract.self,
            reason: "WinUI's WebView2 is no control: it keeps no enabled state, and "
            + "its page takes the user's hand whatever the tree says."),
        .notPlanned(ViewContract.panTouchCount, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.held, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.panUpdated, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.panXChannel, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.panYChannel, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.pinchUpdated, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.pointerEntered, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.pointerExited, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.pointerMoved, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.pointerPressed, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.pointerReleased, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.swipeDirection, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.swipeThreshold, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.swiped, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.tapCount, on: WebViewContract.self, reason: webViewTakesTheHand),
        .notPlanned(ViewContract.tapped, on: WebViewContract.self, reason: webViewTakesTheHand),
        .complete(WindowContract.activated),
        .partial(WindowContract.background, missing: "WinUI has no glass: a window of glass shows the desktop acrylic "
            + "at the glass's fallback thickness."),
        .complete(WindowContract.created),
        .complete(WindowContract.deactivated),
        .complete(WindowContract.destroying),
        .complete(WindowContract.floatsOnTop),
        .complete(WindowContract.height),
        .complete(WindowContract.hidesWhenInactive),
        .complete(WindowContract.isMaximizable),
        .complete(WindowContract.isMinimizable),
        .complete(WindowContract.maximumHeight),
        .complete(WindowContract.maximumWidth),
        .complete(WindowContract.minimumHeight),
        .complete(WindowContract.minimumWidth),
        .complete(WindowContract.resumed),
        .complete(WindowContract.stopped),
        .complete(WindowContract.title),
        .complete(WindowContract.width),
        .complete(WindowContract.windowType),
        .complete(WindowContract.windowValue),
        .complete(WindowContract.x),
        .complete(WindowContract.y),
    ] + HostRecord.layoutEngine

    /// What a split view's pane leaves out of a material.
    static let paneHasNoGlass = "WinUI has no glass: a pane of glass shows the in-app acrylic at its fallback thickness."

    /// Why a figure takes no background on WinUI.
    static let figurePaintsNoGround = "A WinUI shape is its figure alone: it paints no ground around it."

    /// Why an activity ring's press is not let through as the tree says.
    static let hitOnlyWherePainted = "WinUI hands the activity ring only the presses on its turning arc: the "
        + "ring's middle, where a press is read, is never pressed, so there is nothing to let through."

    /// Why a search box's caret is not the program's.
    static let searchCaret = "WinUI's search box keeps its caret in the text box of its template, and offers no "
        + "caret or selection of its own."

    /// Why a web view hears none of the user's hand as a view does.
    static let webViewTakesTheHand = "WebView2 gives the user's hand to its page: listened to by WinUI, it ends the "
        + "process (fail-fast in Microsoft.UI.Xaml.Controls)."

    /// What WinUI's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = WinUIRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames,
            acts: (HostActs.performed + HostActs.files + HostActs.network + [ItemsViewContract.scrollTo]).map(\.name))
    }

    /// Why a control left out with its children is left out alone: WinUI has no property that leaves out a
    /// subtree, and the host reaches into no template's parts.
    private static let partsStayMet =
        "WinUI leaves out the control itself; the parts its template draws stay where assistive technology meets them."

    /// What WinUI realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(
            records: records,
            unrealized: unrealized + unregistered, notPlanned: notPlanned, byApplication: byApplication
        ).and(declaration)
    }
}
