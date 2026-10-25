// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the GTK 4 column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum GTKRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: [any ElementContract.Type] = []

    /// The entries this host leaves to the application, which registers its own control for each: the platform has
    /// no map of its own, and a map needs a provider and its key.
    static let byApplication: [any ElementContract.Type] = [MapContract.self, MarkerContract.self]

    /// The entries a backend realizes on this host - a package of its own, for a library GTK does not ship - which
    /// the application's head registers: WebKitGTK's web view. Realized none of until it is registered.
    static let backends: [any ElementContract.Type] = [WebViewContract.self]

    /// What the running host realizes none of: what it never makes, what it leaves to the application, and each
    /// backend no one registered.
    @MainActor static var unmade: [any ElementContract.Type] {
        unrealized + byApplication + unregistered
    }

    /// Each backend no one registered: realized none of until it is.
    @MainActor static var unregistered: [any ElementContract.Type] {
        backends.filter { !GTKRegistrations.registry.realization.elements.contains($0.nodeType) }
    }

    /// The entries GTK will not have; none.
    static let notPlanned: [(any ElementContract.Type, reason: String)] = []

    /// Every record, the tiers' first.
    /// Why no element is pulled to refresh here.
    private static let noPull = "GTK and libadwaita offer no pull to refresh: a GNOME application refreshes by a "
        + "command - a header bar button, Ctrl+R."

    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .notPlanned(RefreshElementContract.isRefreshEnabled, reason: Self.noPull),
        .notPlanned(RefreshElementContract.isRefreshing, reason: Self.noPull),
        .notPlanned(RefreshElementContract.refreshRequested, reason: Self.noPull),
        .notPlanned(LayoutContract.ignoresSafeArea, reason: "A GNOME window keeps no area of its content clear: its "
            + "header bar stands above the content, over none of it."),
        .notPlanned(AutomationElementContract.accessibilityIdentifier, reason: "GTK 4 tells assistive technology no "
            + "identifier before 4.22, and from 4.22 only a GtkBuilder file's id, which no public call sets on a widget "
            + "made in code."),
        .partial(BarElementContract.barBackground,
            missing: "GNOME blurs nothing inside a window: a blur or glass shows its color."),
        .notPlanned(BarElementContract.barButtonBackgroundColor, reason: "A header bar's buttons are libadwaita's own, flat."),
        .notPlanned(BarElementContract.toolbarStyle, reason: "The header bar's buttons keep libadwaita's own look."),
        .complete(BarElementContract.barForegroundColor),
        .complete(MenuBarContract.order),
        .complete(MenuContract.isEnabled),
        .complete(MenuContract.text),
        .complete(MenuToggleContract.isOn),
        .complete(MenuItemElementContract.keyboardShortcut, on: MenuItemContract.self),
        .complete(MenuItemElementContract.keyboardShortcut, on: MenuToggleContract.self),
        .complete(MenuToggleContract.toggled),
        .complete(ActionElementContract.clicked),
        .complete(MenuItemElementContract.icon),
        .complete(MenuItemElementContract.isEnabled),
        .complete(MenuItemElementContract.text),
        .notPlanned(PageElementContract.icon,
            reason: "GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions."),
        .complete(PageElementContract.title),
        .notPlanned(VisualElementContract.accessibilityActionPerformed,
            reason: "GTK's accessibility offers no action of an application's own words."),
        .notPlanned(VisualElementContract.accessibilityActions,
            reason: "GTK's accessibility offers no action of an application's own words."),
        .notPlanned(VisualElementContract.accessibilityAdjusted,
            reason: "GTK steps only a range, a role a widget takes as it is made."),
        .notPlanned(ApplicationContract.share, reason: "GNOME offers an application no share sheet."),
        .notPlanned(VisualElementContract.accessibilityRole,
            reason: "GTK fixes a widget's role as it is made, and a widget is the kind its class says."),
        .notPlanned(VisualElementContract.accessibilityValue,
            reason: "GTK says a value only of a range, a role a widget takes as it is made."),
        .partial(ViewContract.holdDuration,
            missing: "GTK waits from half to twice its long-press time: a time beyond either stands at that end."),
        .partial(VisualElementContract.accessibilityHeading,
            missing: "GTK fixes a widget's role once it is shown: a view "
            + "becomes a heading, or stops being one, only as it is made; its level changes."),
        .partial(FilledShapeContract.fill, missing: "GTK blurs nothing behind a figure: a blur or glass shows the theme's color standing in, its tint over it."),
        .partial(VisualElementContract.background,
            missing: "A brush fills the view with its first color alone; GTK blurs nothing behind a widget, so a blur or glass shows the theme's color standing in, its tint over it."),
        .complete(VisualElementContract.layoutDirection),
        .complete(VisualElementContract.style),

        // MARK: Entries - a control's or a part's own
        .complete(ButtonMenuElementContract.menuKind, on: ButtonContract.self),
        .complete(ButtonMenuElementContract.menuKind, on: ToolbarButtonContract.self),
        .complete(ButtonMenuElementContract.showsMenuArrow, on: ButtonContract.self),
        .complete(TextAndIconElementContract.showsText, on: ButtonContract.self),
        .complete(ButtonMenuElementContract.showsMenuArrow, on: ToolbarButtonContract.self),
        .notPlanned(PageContract.backButtonTitle, reason: "GNOME's way back in the bar is an arrow, with no words."),
        .partial(SearchFieldContract.submitLabel,
            missing: "The return key's word: GTK gives an entry no word for the return key of a keyboard on the screen; Next "
            + "hands the keyboard on all the same."),
        .notPlanned(TextFieldContract.showsClearButton,
            reason: "GTK's entry has no button of its own that empties it."),
        .partial(TextInputContract.inputPurpose,
            missing: "Filling in: GNOME keeps no saved names, passwords or codes to fill a field in from; a name, a "
            + "password and a code get their keys and checking all the same."),
        .partial(TextFieldContract.submitLabel,
            missing: "The return key's word: GTK gives an entry no word for the return key of a keyboard on the screen; Next "
            + "hands the keyboard on all the same."),
        .complete(VisualElementContract.background, on: GridContract.self),
        .complete(VisualElementContract.background, on: HStackContract.self),
        .complete(VisualElementContract.background, on: ScrollViewContract.self),
        .notPlanned(VisualElementContract.background, on: SwitchContract.self,
            reason: "GTK's switch paints its own box as its track: a color there would "
            + "recolor the track, not lie under it."),
        .complete(VisualElementContract.background, on: VStackContract.self),
        .complete(VisualElementContract.background, on: ZStackContract.self),
        .complete(VisualElementContract.background, on: FillContract.self),
        .complete(VisualElementContract.background, on: SpaceContract.self),
        .complete(VisualElementContract.background, on: LayoutEngineContract.self),
        .complete(LayoutEngineContract.handAxis),
        .complete(LayoutEngineContract.handMoved),
        .complete(LayoutEngineContract.handStepped),
        .complete(LayoutEngineContract.itemDrag),
        .complete(LayoutEngineContract.itemMoved),
        .complete(LayoutEngineContract.magnifies),
        .complete(LayoutEngineContract.pans),
        .complete(LayoutEngineContract.rotates),
        .complete(LayoutEngineContract.pinchMoved),
        .partial(DatePickerContract.format,
            missing: "GTK writes the long and the short day in the user's own way, and the medium as the short."),
        .partial(DatePickerContract.maximumDate,
            missing: "GtkCalendar offers every day: one the user picks past the range stands at its end."),
        .partial(DatePickerContract.minimumDate,
            missing: "GtkCalendar offers every day: one the user picks past the range stands at its end."),
        .unrealized(VisualElementContract.style, on: ItemsViewContract.self,
            why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .notPlanned(MenuItemElementContract.icon, on: MenuItemContract.self,
            reason: "GNOME's menus show words alone, no picture beside them."),
        .notPlanned(MenuItemElementContract.icon, on: MenuToggleContract.self,
            reason: "GNOME's menus show words alone, no picture beside them."),
        .notPlanned(ActionElementContract.role, on: MenuItemContract.self,
            reason: "GNOME's menus mark no entry as destroying something."),
        .complete(SheetContract.isPresented),
        .complete(SheetContract.isPresentedChanged),
        .complete(NavigationStackContract.popped),
        .complete(PageContract.appearing),
        .complete(PageElementContract.background),
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
        .notPlanned(PickerContract.closed, reason: "GTK's drop-down tells no one its list opened or closed."),
        .notPlanned(TextAlignmentElementContract.horizontalTextAlignment, on: PickerContract.self,
            reason: "GTK's drop-down draws its choice with the factory "
            + "that draws its list: the choice alone takes no alignment without redrawing GNOME's list."),
        .notPlanned(PickerContract.isOpen, reason: "GTK's drop-down tells no one its list opened or closed."),
        .notPlanned(PickerContract.opened, reason: "GTK's drop-down tells no one its list opened or closed."),
        .notPlanned(TintElementContract.tint, on: PickerContract.self,
            reason: "A GNOME drop-down wears no accent: a check in its words' color marks the choice."),
        .notPlanned(PickerContract.placeholder,
            reason: "GTK's drop-down shows a choice or nothing: it has no words standing for none."),
        .complete(SceneContract.activated),
        .complete(SceneContract.deactivated),
        .complete(SceneContract.stopped),
        .complete(SceneContract.windowClosed),
        .notPlanned(SliderContract.released, reason: "GTK's scale tells no one it is held: its range claims the "
            + "press, and GTK denies every other gesture on it."),
        .notPlanned(SliderContract.pressed, reason: "GTK's scale tells no one it is held: its range claims the "
            + "press, and GTK denies every other gesture on it."),
        .complete(TextSpanContract.background),
        .complete(TrackingElementContract.tracking, on: TextSpanContract.self),
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
        .complete(SplitViewContract.showsSidebar),
        .complete(SplitViewContract.showsSidebarChanged),
        .complete(SplitViewContract.showsSidebarToggle),
        .partial(SplitViewContract.sidebarBackground,
            missing: "GTK blurs nothing inside a window: a blur or glass shows its color."),
        .partial(SplitViewContract.sidebarOverlayBackground,
            missing: "GTK blurs nothing inside a window: a blur or glass shows its color."),
        .complete(SplitViewContract.sidebarOverlays),
        .complete(TabViewContract.selectedTab),
        .complete(TabViewContract.selectedTabChanged),
        .partial(VisualElementContract.layoutDirection, on: TextEditorContract.self,
            missing: "Its placeholder stands at the left edge whichever way the words are written."),
        .partial(TimePickerContract.format,
            missing: "GTK writes hours and minutes in the user's own clock, whatever the format asks: no seconds, no pattern."),
        .complete(ActionElementContract.role, on: ToolbarButtonContract.self),
        .complete(MenuItemElementContract.keyboardShortcut, on: ToolbarButtonContract.self),
        .complete(TextAndIconElementContract.showsText, on: ToolbarButtonContract.self),
        .complete(MenuItemElementContract.keyboardShortcut, on: ToolbarToggleContract.self),
        .complete(ToolbarToggleContract.isOn),
        .complete(ToolbarToggleContract.onIcon),
        .complete(TextAndIconElementContract.showsText, on: ToolbarToggleContract.self),
        .complete(ToolbarToggleContract.toggled),
        .complete(ToolbarGroupContract.order),
        .complete(ToolbarGroupContract.isEnabled),
        .complete(ToolbarGroupContract.position),
        .complete(WindowContract.activated),
        .complete(WindowContract.created),
        .complete(WindowContract.deactivated),
        .complete(WindowContract.destroying),
        .notPlanned(WindowContract.floatsOnTop,
            reason: "GTK 4 keeps no window above the others: the desktop stacks them."),
        .complete(WindowContract.height),
        .complete(WindowContract.hidesWhenInactive),
        .notPlanned(WindowContract.isMaximizable,
            reason: "The desktop fills the screen with any GTK 4 window it can resize: none forbids that alone."),
        .notPlanned(WindowContract.isMinimizable,
            reason: "GTK 4 asks the desktop to keep no window from being put away."),
        .partial(WindowContract.background,
            missing: "GNOME draws its windows opaque: a blur or glass shows its color."),
        .notPlanned(WindowContract.maximumHeight, reason: "GTK 4 bounds no window from above."),
        .notPlanned(WindowContract.maximumWidth, reason: "GTK 4 bounds no window from above."),
        .complete(WindowContract.minimumHeight),
        .complete(WindowContract.minimumWidth),
        .partial(WindowContract.resumed,
            missing: "A Wayland desktop tells no window it was minimized, nor brought back."),
        .partial(WindowContract.stopped,
            missing: "A Wayland desktop tells no window it was minimized, nor brought back."),
        .complete(WindowContract.title),
        .complete(WindowContract.width),
        .complete(WindowContract.windowType),
        .complete(WindowContract.windowValue),
        .notPlanned(WindowContract.x, reason: "GNOME places its windows itself: GTK 4 asks no place of the desktop."),
        .notPlanned(WindowContract.y, reason: "GNOME places its windows itself: GTK 4 asks no place of the desktop."),
    ] + HostRecord.layoutEngine

    /// What GTK's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = GTKRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames, acts: GTKRegistrations.acts.map(\.name))
    }

    /// What GTK realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(
            records: records,
            unrealized: unrealized + unregistered, notPlanned: notPlanned, byApplication: byApplication
        ).and(declaration)
    }
}
