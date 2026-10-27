// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the Android Views column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum AndroidRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: [any ElementContract.Type] = []

    /// The entries this host leaves to the application, which registers its own control for each: the platform has
    /// no map of its own, and a map needs a provider and its key.
    static let byApplication: [any ElementContract.Type] = [MapContract.self, MarkerContract.self]

    /// What the running host realizes none of: what it never makes, and what it leaves to the application.
    static var unmade: [any ElementContract.Type] {
        unrealized + byApplication
    }

    /// The entries a phone will not have: what Android has no control of its own for.
    static let notPlanned: [(any ElementContract.Type, reason: String)] = [
        (ColorPickerContract.self,
         reason: "Android has no color picker of its own: neither the platform nor its own libraries offer one."),
    ]

    /// Every record, the tiers' first.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .partial(FilledShapeContract.fill, missing: "Android blurs nothing behind a figure: a blur or glass shows the theme's color standing in, its tint over it."),
        .partial(VisualElementContract.background,
            missing: "Android blurs nothing behind a view: a blur or glass shows the theme's color standing in, its tint over it."),
        .partial(BarElementContract.barBackground, missing: Self.blursNothing),
        .notPlanned(BarElementContract.barButtonBackgroundColor, reason: "A toolbar's action is Android's own, with no background of the application's."),
        .notPlanned(BarElementContract.toolbarStyle, reason: "The toolbar's actions keep Android's own look."),
        .complete(BarElementContract.barButtonFontWeight),
        .partial(BarElementContract.barForegroundColor,
            missing: "The actions' words take the bar's light or dark theme, as Android's own bars do; the title, the line under it, the navigation button and the pictures take the color itself - on a tab row, the chosen tab's words."),
        .complete(ButtonContract.keyboardShortcut),
        .complete(ButtonMenuElementContract.menuKind, on: ButtonContract.self),
        .partial(ButtonMenuElementContract.menuKind, on: ToolbarButtonContract.self,
            missing: "An Android bar's split or held button stands as its action, its menu behind the overflow."),
        .complete(ButtonMenuElementContract.showsMenuArrow, on: ButtonContract.self),
        .complete(TextAndIconElementContract.showsText, on: ButtonContract.self),
        .notPlanned(ButtonMenuElementContract.showsMenuArrow, on: ToolbarButtonContract.self,
            reason: "An Android bar's action shows no arrow: its menu opens from its touch."),
        .partial(ButtonContract.role,
            missing: "Android draws no look for the way out or a destructive action, only the main action's colored button."),
        .complete(MenuToggleContract.isOn),
        .complete(MenuItemElementContract.keyboardShortcut, on: MenuItemContract.self),
        .complete(MenuItemElementContract.keyboardShortcut, on: MenuToggleContract.self),
        .complete(MenuToggleContract.toggled),
        .complete(ActionElementContract.clicked),
        .complete(ActionElementContract.role),
        .complete(MenuItemElementContract.isEnabled),
        .complete(MenuItemElementContract.text),
        .complete(PageElementContract.icon),
        .complete(PageElementContract.title),
        .partial(VisualElementContract.accessibilityRole,
            missing: "A link: Android names no kind for one, and the view is said as what it is."),
        .partial(VisualElementContract.accessibilityValue,
            missing: "Before Android 11 a view says no value of its own words."),
        .partial(VisualElementContract.accessibilityHeading,
            missing: "Android marks a heading, not its level: every level is a heading."),
        .partial(ViewContract.panTouchCount,
            missing: "The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off."),
        .notPlanned(ViewContract.holdDuration,
            reason: "Android's long click comes after the system's long-press time: a view keeps no time of its own."),
        .notPlanned(ViewContract.held, on: CanvasContract.self, reason: Self.ownPress),
        .notPlanned(ViewContract.held, on: ItemsViewContract.self, reason: Self.ownPress),
        .notPlanned(ViewContract.held, on: ScrollViewContract.self, reason: Self.ownPress),
        .notPlanned(ViewContract.held, on: SliderContract.self, reason: Self.ownPress),
        .notPlanned(ViewContract.held, on: StepperContract.self, reason: Self.ownPress),
        .complete(VisualElementContract.style),

        // MARK: Entries - a control's or a part's own
        .partial(ImageElementContract.contentMode, on: ButtonContract.self,
            missing: "Android's button has no covering scale: `.fill` fits the icon, as `.fit` does."),
        .notPlanned(VisualElementContract.zIndex, on: ButtonContract.self,
            reason: "Android draws a raised button over the flat views beside it whatever their depth: its elevation is the native button's own."),
        .unrealized(VisualElementContract.style, on: ItemsViewContract.self,
            why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .complete(MenuContract.isEnabled),
        .complete(MenuContract.text),
        .complete(MenuBarContract.order),
        .complete(SheetContract.isPresented),
        .complete(SheetContract.isPresentedChanged),
        .complete(VisualElementContract.layoutDirection),
        .notPlanned(TextFieldContract.showsClearButton,
            reason: "Android's text field has no button of its own that empties it."),
        .notPlanned(PageContract.backButtonTitle, reason: "Android's way back in the bar is an arrow, with no words."),
        .notPlanned(TextInputContract.isSpellCheckEnabled,
            reason: "Android has no switch for spell checking alone: its marks go with the suggestions, which `isTextPredictionEnabled` turns off."),
        .notPlanned(AutomationElementContract.accessibilityIdentifier, on: MenuItemContract.self,
            reason: "An Android menu entry holds no identifier: automation finds it by its title."),
        .notPlanned(AutomationElementContract.accessibilityIdentifier, on: MenuToggleContract.self,
            reason: "An Android menu entry holds no identifier: automation finds it by its title."),
        .notPlanned(MenuItemElementContract.icon, on: MenuItemContract.self,
            reason: "Android's menus - a view's context menu, a bar's overflow and its submenus - draw their entries' words alone."),
        .notPlanned(MenuItemElementContract.icon, on: MenuToggleContract.self,
            reason: "Android's menus - a view's context menu, a bar's overflow and its submenus - draw their entries' words alone."),
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
        .partial(PickerContract.isOpen,
            missing: "Android closes the list only when the user does: `false` does not close it."),
        .complete(SceneContract.activated),
        .complete(SceneContract.deactivated),
        .complete(SceneContract.stopped),
        .complete(TextSpanContract.background),
        .partial(PickerContract.presentation,
            missing: "Android has no segmented control: `.segmented` is a radio group "
            + "in a row."),
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
        .notPlanned(TrackingElementContract.tracking, on: TextSpanContract.self,
            reason: "Android spaces the letters of a whole text: no span spaces a run's own."),
        .complete(SplitViewContract.showsSidebar),
        .complete(SplitViewContract.showsSidebarChanged),
        .complete(SplitViewContract.showsSidebarToggle),
        .partial(SplitViewContract.sidebarBackground, missing: Self.blursNothing),
        .partial(SplitViewContract.sidebarOverlayBackground, missing: Self.blursNothing),
        .complete(SplitViewContract.sidebarOverlays),
        .complete(TabViewContract.selectedTab),
        .complete(TabViewContract.selectedTabChanged),
        .notPlanned(AutomationElementContract.accessibilityIdentifier, on: ToolbarButtonContract.self,
            reason: "An Android bar action is a menu entry, which holds no identifier: automation finds it by its title."),
        .complete(MenuItemElementContract.icon, on: ToolbarButtonContract.self),
        .complete(MenuItemElementContract.keyboardShortcut, on: ToolbarButtonContract.self),
        .partial(TextAndIconElementContract.showsText, on: ToolbarButtonContract.self,
            missing: "Android shows the words beside the picture only where the bar has room: an upright phone keeps the picture alone."),
        .notPlanned(AutomationElementContract.accessibilityIdentifier, on: ToolbarToggleContract.self,
            reason: "An Android bar action is a menu entry, which holds no identifier: automation finds it by its title."),
        .complete(MenuItemElementContract.icon, on: ToolbarToggleContract.self),
        .complete(MenuItemElementContract.keyboardShortcut, on: ToolbarToggleContract.self),
        .partial(ToolbarToggleContract.isOn,
            missing: "An Android bar shows a setting's state by its on picture alone; behind the overflow, by its check."),
        .complete(ToolbarToggleContract.onIcon),
        .partial(TextAndIconElementContract.showsText, on: ToolbarToggleContract.self,
            missing: "Android shows the words beside the picture only where the bar has room: an upright phone keeps the picture alone."),
        .complete(ToolbarToggleContract.toggled),
        .complete(ToolbarGroupContract.order),
        .complete(ToolbarGroupContract.part),
        .complete(ToolbarGroupContract.hidesWithSidebar),
        .complete(ToolbarGroupContract.isEnabled),
        .partial(ToolbarGroupContract.position,
            missing: "Android's bar has no leading edge beside its navigation button: a leading group stands first among the actions."),
        .notPlanned(ToolbarGroupContract.standsAlone,
            reason: "Android's bar draws its actions with no background behind a group."),
        .notPlanned(ApplicationContract.useAccentColor,
            reason: "Android draws its controls in the theme's accent, set before the activity starts - from 12 the user's."),
        .complete(ApplicationContract.useColorScheme),
        .complete(WindowContract.activated),
        .complete(WindowContract.created),
        .complete(WindowContract.deactivated),
        .complete(WindowContract.destroying),
        .complete(WindowContract.resumed),
        .complete(WindowContract.stopped),
        .complete(WindowContract.title),
        .notPlanned(WindowContract.floatsOnTop,
            reason: "Android stacks windows itself: an activity keeps none above the others."),
        .notPlanned(WindowContract.hidesWhenInactive,
            reason: "Android shows an activity itself: it hides none while another application is in front."),
        .notPlanned(WindowContract.isMaximizable,
            reason: "Any Android window may fill the screen: an activity keeps none from it."),
        .notPlanned(WindowContract.isMinimizable,
            reason: "Any Android window may be put away: an activity keeps none from it."),
        .partial(WindowContract.background,
            missing: "An activity is opaque by the theme it starts in: a blur or glass shows its color."),
        .complete(PhaseLayoutContract.handAxis),
        .complete(PhaseLayoutContract.handMoved),
        .complete(PhaseLayoutContract.handStepped),
        .complete(PhaseLayoutContract.itemDrag),
        .complete(PhaseLayoutContract.itemMoved),
        .complete(PhaseLayoutContract.magnifies),
        .complete(PhaseLayoutContract.pans),
        .complete(PhaseLayoutContract.rotates),
        .complete(PhaseLayoutContract.pinchMoved),
    ] + windowRoom + HostRecord.phaseLayout

    /// What Android leaves out of a blur.
    private static let ownPress = "The control takes its own press - a drawing, a scroll, a thumb, its buttons: "
        + "Android tells no long click of it."
    private static let blursNothing = "Android blurs nothing behind a view: a blur or glass shows its color."

    /// The window's place and size, which Android gives an activity itself.
    private static let windowRoom: [HostRecord] = {
        let placed = "Android places an activity's window itself: an activity asks for no place."
        let sized = "Android sizes an activity's window itself - the user drags its edge: an activity asks for no size."
        let bounded = "Android bounds an activity's window itself: an activity sets it no bound at run time."
        return [
            .notPlanned(WindowContract.x, reason: placed), .notPlanned(WindowContract.y, reason: placed),
            .notPlanned(WindowContract.width, reason: sized), .notPlanned(WindowContract.height, reason: sized),
            .notPlanned(WindowContract.minimumWidth,
                reason: bounded), .notPlanned(WindowContract.minimumHeight, reason: bounded),
            .notPlanned(WindowContract.maximumWidth,
                reason: bounded), .notPlanned(WindowContract.maximumHeight, reason: bounded),
        ]
    }()

    /// What Android's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = AndroidRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames,
            acts: AndroidRegistrations.acts.map(\.name))
    }

    /// What Android realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(
            records: records, unrealized: unrealized, notPlanned: notPlanned,
            byApplication: byApplication
        ).and(declaration)
    }
}
