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

    /// The entries a phone will not have; none yet.
    static let notPlanned: [(any ElementContract.Type, reason: String)] = []

    /// Every record, the tiers' first.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .partial(VisualElementContract.background,
            missing: "Android blurs nothing behind a view: a blur or glass shows the theme's colour standing in, its tint over it."),
        .complete(BarElementContract.barBackgroundColor),
        .partial(BarElementContract.barForegroundColor,
            missing: "The actions' words take the bar's light or dark theme, as Android's own bars do; the title, the line under it, the navigation button and the pictures take the colour itself - on a tab row, the chosen tab's words."),
        .notPlanned(BarElementContract.barIcon,
            reason: "An Android bar is its stack's own: it shows its page's title, and no application's mark."),
        .complete(BarElementContract.barSubtitle),
        .notPlanned(BarElementContract.barTitle,
            reason: "An Android bar is its stack's own and names its page; an application names itself in none."),
        .complete(ButtonContract.keyboardShortcut),
        .complete(ButtonContract.menuKind),
        .complete(ButtonContract.showsMenuArrow),
        .partial(ButtonContract.role,
            missing: "Android draws no look for the way out or a destructive action, only the main action's coloured button."),
        .complete(MenuItemContract.isOn),
        .complete(MenuItemElementContract.keyboardShortcut, on: MenuItemContract.self),
        .complete(MenuItemContract.toggled),
        .complete(MenuItemElementContract.clicked),
        .complete(MenuItemElementContract.role),
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
        .complete(ModalStackContract.popped),
        .complete(VisualElementContract.layoutDirection),
        .notPlanned(TextFieldContract.showsClearButton,
            reason: "Android's text field has no button of its own that empties it."),
        .notPlanned(PageContract.backButtonTitle, reason: "Android's way back in the bar is an arrow, with no words."),
        .notPlanned(TextInputContract.isSpellCheckEnabled,
            reason: "Android has no switch for spell checking alone: its marks go with the suggestions, which `isTextPredictionEnabled` turns off."),
        .notPlanned(AutomationElementContract.accessibilityIdentifier, on: MenuItemContract.self,
            reason: "An Android menu entry holds no identifier: automation finds it by its title."),
        .notPlanned(MenuItemElementContract.icon, on: MenuItemContract.self,
            reason: "Android's menus - a view's context menu, a bar's overflow and its submenus - draw their entries' words alone."),
        .complete(NavigationStackContract.popped),
        .complete(PageContract.appearing),
        .complete(PageContract.background),
        .complete(PageContract.disappearing),
        .complete(PageContract.showsBackButton),
        .complete(PageContract.showsNavigationBar),
        .complete(PageContract.showsTitle),
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
        .partial(SplitViewContract.sidebarBackground, missing: Self.blursNothing),
        .partial(SplitViewContract.flyoutBackground, missing: Self.blursNothing),
        .complete(SplitViewContract.sidebarOverlays),
        .complete(TabViewContract.selectedTab),
        .complete(TabViewContract.selectedTabChanged),
        .notPlanned(AutomationElementContract.accessibilityIdentifier, on: ToolbarItemContract.self,
            reason: "An Android bar action is a menu entry, which holds no identifier: automation finds it by its title."),
        .complete(MenuItemElementContract.icon, on: ToolbarItemContract.self),
        .complete(MenuItemElementContract.keyboardShortcut, on: ToolbarItemContract.self),
        .complete(ToolbarItemContract.placement),
        .partial(ToolbarItemContract.showsText,
            missing: "Android shows the words beside the picture only where the bar has room: an upright phone keeps the picture alone."),
        .complete(ToolbarItemGroupContract.order),
        .notPlanned(ToolbarItemGroupContract.side,
            reason: "Android's bar has no leading edge beside its navigation button: a leading group stands first among the actions."),
        .partial(ApplicationContract.useColorScheme, missing: "Before Android 12 an application holds no night mode "
            + "of its own: it shows the system's."),
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
            missing: "An activity is opaque by the theme it starts in: a blur or glass shows its colour."),
        .complete(LayoutEngineContract.handAxis),
        .complete(LayoutEngineContract.handMoved),
        .complete(LayoutEngineContract.handStepped),
        .complete(LayoutEngineContract.itemDrag),
        .complete(LayoutEngineContract.itemMoved),
        .complete(LayoutEngineContract.magnifies),
        .complete(LayoutEngineContract.pans),
        .complete(LayoutEngineContract.rotates),
        .complete(LayoutEngineContract.pinchMoved),
    ] + windowRoom + HostRecord.layoutEngine

    /// What Android leaves out of a blur.
    private static let blursNothing = "Android blurs nothing behind a view: a blur or glass shows its colour."

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
