// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the AppKit column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum AppKitRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: [any ElementContract.Type] = []

    /// The entries the Mac will not have; none.
    static let notPlanned: [(any ElementContract.Type, reason: String)] = []

    /// Why a reader's steps reach no element AppKit shows through a view of its own.
    static let ownSteps = "VoiceOver meets AppKit's own view here - a control, a box, a scroller, a map, a page - "
        + "which steps as its own kind does, or not at all; a view StateUI draws takes a reader's steps."

    /// Every record, the tiers' first.
    /// Why no element is pulled to refresh here.
    private static let noPull = "AppKit offers no pull to refresh: a Mac application refreshes by a command - a "
        + "menu item, a toolbar button, ⌘R."

    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .notPlanned(RefreshElementContract.isRefreshEnabled, reason: Self.noPull),
        .notPlanned(RefreshElementContract.isRefreshing, reason: Self.noPull),
        .notPlanned(RefreshElementContract.refreshRequested, reason: Self.noPull),
        .notPlanned(ApplicationContract.useAccentColor, reason: "macOS draws every control in the accent the user chose."),
        .complete(BarElementContract.barBackgroundColor),
        .notPlanned(BarElementContract.barButtonBackgroundColor, reason: "A toolbar item stands in the Mac's own look, with no background of the application's."),
        .notPlanned(BarElementContract.toolbarStyle, reason: "The toolbar's items keep the Mac's own look."),
        .partial(BarElementContract.barForegroundColor,
            missing: "Only the title takes it, over a band painted in a bar color; the toolbar's items keep the system's color."),
        .complete(DecorableTextElementContract.textDecorations),
        .complete(LineHeightElementContract.lineHeight),
        .complete(MenuToggleContract.isOn),
        .complete(MenuItemElementContract.keyboardShortcut, on: MenuItemContract.self),
        .complete(MenuItemElementContract.keyboardShortcut, on: MenuToggleContract.self),
        .complete(MenuToggleContract.toggled),
        .complete(ActionElementContract.clicked),
        .complete(MenuItemElementContract.icon),
        .complete(MenuItemElementContract.isEnabled),
        .complete(MenuItemElementContract.text),
        .complete(PageElementContract.icon),
        .complete(PageElementContract.title),
        .complete(LayoutContract.clipsContent),
        .partial(VisualElementContract.accessibilityHeading,
            missing: "AppKit marks a heading, not its level: every level is a heading."),
        .partial(TextInputContract.inputPurpose,
            missing: "A Mac has no keyboard on the screen: a purpose sets capitals, spell checking, correction, "
            + "prediction and what macOS fills the words in with, no keys."),
        .partial(VisualElementContract.background,
            missing: "AppKit paints a color on this view; a brush, a blur and glass are drawn only by a layout, and elsewhere a blur's color stands in."),
        .partial(ViewContract.panTouchCount,
            missing: "The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off."),
        .complete(VisualElementContract.layoutDirection),
        .complete(VisualElementContract.style),
        .notPlanned(FontElementContract.isFontAutoScalingEnabled,
            reason: "macOS gives an application no text size of the user's to follow."),
        .notPlanned(FontElementContract.isFontAutoScalingEnabled, on: TextSpanContract.self,
            reason: "macOS gives an application no text size of the user's to follow."),

        // MARK: Entries - a control's or a part's own, and where it differs from its tier
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: SpinnerContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: ButtonContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: LinkContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: CheckBoxContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: DatePickerContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: SeparatorContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: ItemsViewContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: MapContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: PickerContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: ProgressBarContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: ScrollViewContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: SearchFieldContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: SliderContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: StepperContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: SwitchContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: TextEditorContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: TextFieldContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: TimePickerContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: WebViewContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityValue, on: SliderContract.self,
            reason: "AppKit's slider says its own number to assistive technology, over any value given."),
        .notPlanned(VisualElementContract.accessibilityValue, on: DatePickerContract.self,
            reason: "AppKit's date picker says its own date to assistive technology, over any value given."),
        .notPlanned(VisualElementContract.accessibilityValue, on: TimePickerContract.self,
            reason: "AppKit's date picker says its own time to assistive technology, over any value given."),
        .partial(TextFieldContract.submitLabel,
            missing: "The return key's word: a Mac has no keyboard on the screen whose return key says anything; Next "
            + "hands the keyboard on all the same."),
        .partial(SearchFieldContract.submitLabel,
            missing: "The return key's word: a Mac has no keyboard on the screen whose return key says anything; Next "
            + "hands the keyboard on all the same."),
        .notPlanned(TextFieldContract.showsClearButton,
            reason: "AppKit's text field has no button of its own that empties it."),
        .unrealized(VisualElementContract.style, on: ItemsViewContract.self,
            why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .partial(ImageElementContract.contentMode, on: ButtonContract.self,
            missing: "AppKit's button has no covering scale: `.fill` fits the icon, as `.fit` does."),
        .complete(ButtonMenuElementContract.menuKind, on: ButtonContract.self),
        .complete(ButtonMenuElementContract.menuKind, on: ToolbarButtonContract.self),
        .complete(PaddingElementContract.padding, on: ButtonContract.self),
        .complete(ButtonMenuElementContract.showsMenuArrow, on: ButtonContract.self),
        .complete(TextAndIconElementContract.showsText, on: ButtonContract.self),
        .complete(ButtonMenuElementContract.showsMenuArrow, on: ToolbarButtonContract.self),
        .complete(ButtonContract.role),
        .complete(AutomationElementContract.accessibilityIdentifier, on: TextContract.self),
        .complete(TrackingElementContract.tracking, on: TextContract.self),
        .complete(FontElementContract.fontAttributes, on: TextContract.self),
        .complete(FontElementContract.fontWeight, on: TextContract.self),
        .complete(FontElementContract.textStyle, on: TextContract.self),
        .complete(FontElementContract.fontFamily, on: TextContract.self),
        .complete(FontElementContract.fontSize, on: TextContract.self),
        .complete(TextAlignmentElementContract.horizontalTextAlignment, on: TextContract.self),
        .complete(VisualElementContract.ignoresInput, on: TextContract.self),
        .complete(TextContract.isSelectable),
        .complete(TextContract.lineBreak),
        .complete(TextContract.maximumLines),
        .complete(PaddingElementContract.padding, on: TextContract.self),
        .complete(TextualElementContract.textCase, on: TextContract.self),
        .complete(TextColorElementContract.textColor, on: TextContract.self),
        .complete(TextContract.verticalTextAlignment),
        .complete(MenuContract.isEnabled),
        .complete(MenuContract.text),
        .complete(MenuBarContract.order),
        .partial(AutomationElementContract.accessibilityIdentifier, on: MenuItemContract.self,
            missing: "Only an entry of a context menu carries it; an entry the page puts in the menu bar does not."),
        .partial(AutomationElementContract.accessibilityIdentifier, on: MenuToggleContract.self,
            missing: "Only an entry of a context menu carries it; an entry the page puts in the menu bar does not."),
        .complete(ActionElementContract.role, on: MenuItemContract.self),
        .complete(SheetContract.isPresented),
        .complete(SheetContract.isPresentedChanged),
        .complete(PopoverContract.isPresented),
        .complete(PopoverContract.isPresentedChanged),
        .complete(AutomationElementContract.accessibilityIdentifier, on: NavigationStackContract.self),
        .complete(NavigationStackContract.popped),
        .complete(PageContract.appearing),
        .complete(PageContract.backButtonTitle),
        .complete(PageContract.disappearing),
        .complete(PageContract.showsBackButton),
        .complete(PageContract.showsCloseButton),
        .complete(PageContract.showsNavigationBar),
        .complete(PageContract.showsTitle),
        .complete(PageContract.subtitle),
        // A page is no `VisualElement`: it wears `PageElement` alone, so the
        // tier's record about a background does not reach it.
        .complete(PageContract.background),
        .complete(PageElementContract.icon, on: PageContract.self),
        .complete(PageContract.navigatedFrom),
        .complete(PageContract.navigatedTo),
        .complete(PageContract.navigatingFrom),
        .complete(PageElementContract.title, on: PageContract.self),
        .complete(PickerContract.presentation),
        .complete(SceneContract.activated),
        .complete(SceneContract.deactivated),
        .complete(SceneContract.stopped),
        .complete(SceneContract.windowClosed),
        .complete(ScrollViewContract.scrollStopped),
        .complete(TextSpanContract.background),
        .complete(FontElementContract.fontAttributes, on: TextSpanContract.self),
        .complete(FontElementContract.fontWeight, on: TextSpanContract.self),
        .complete(FontElementContract.textStyle, on: TextSpanContract.self),
        .complete(FontElementContract.fontFamily, on: TextSpanContract.self),
        .complete(FontElementContract.fontSize, on: TextSpanContract.self),
        .complete(TextualElementContract.text, on: TextSpanContract.self),
        .complete(TextualElementContract.textCase, on: TextSpanContract.self),
        .complete(TextColorElementContract.textColor, on: TextSpanContract.self),
        .complete(DecorableTextElementContract.textDecorations, on: TextSpanContract.self),
        .complete(TrackingElementContract.tracking, on: TextSpanContract.self),
        .complete(SplitViewContract.showsSidebarChanged),
        .complete(SplitViewContract.showsSidebarToggle),
        .complete(SplitViewContract.sidebarOverlays),
        .notPlanned(SplitViewContract.flyoutBackground,
            reason: "A Mac sidebar always stands beside the detail: a window too narrow for both hides it."),
        .complete(AutomationElementContract.accessibilityIdentifier, on: TabViewContract.self),
        .complete(TabViewContract.selectedTab),
        .complete(TabViewContract.selectedTabChanged),
        .complete(MenuItemElementContract.keyboardShortcut, on: ToolbarButtonContract.self),
        .complete(MenuItemElementContract.keyboardShortcut, on: ToolbarToggleContract.self),
        .notPlanned(TextAndIconElementContract.showsText, on: ToolbarButtonContract.self,
            reason: "A Mac shows a toolbar's words as its user sets the whole toolbar, not item by item."),
        .notPlanned(TextAndIconElementContract.showsText, on: ToolbarToggleContract.self,
            reason: "A Mac shows a toolbar's words as its user sets the whole toolbar, not item by item."),
        .complete(ToolbarToggleContract.isOn),
        .complete(ToolbarToggleContract.onIcon),
        .complete(ToolbarToggleContract.toggled),
        .unrealized(AutomationElementContract.accessibilityIdentifier, on: ToolbarButtonContract.self,
            why: "An NSToolbarItem holds no accessibility identifier."),
        .unrealized(AutomationElementContract.accessibilityIdentifier, on: ToolbarToggleContract.self,
            why: "An NSToolbarItem holds no accessibility identifier."),
        .complete(ToolbarGroupContract.order),
        .complete(ToolbarGroupContract.isEnabled),
        .complete(ToolbarGroupContract.position),
        .complete(WindowContract.activated),
        .partial(WindowContract.background, missing: "A window's glass is drawn as the blur as clear as it is."),
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
        .complete(VisualElementContract.background, on: GridContract.self),
        .complete(BorderElementContract.shape, on: GridContract.self),
        .complete(BorderElementContract.lineWidth, on: GridContract.self),
        .complete(BorderElementContract.stroke, on: GridContract.self),
        .complete(VisualElementContract.background, on: HStackContract.self),
        .complete(BorderElementContract.shape, on: HStackContract.self),
        .complete(BorderElementContract.lineWidth, on: HStackContract.self),
        .complete(BorderElementContract.stroke, on: HStackContract.self),
        .complete(VisualElementContract.background, on: VStackContract.self),
        .complete(BorderElementContract.shape, on: VStackContract.self),
        .complete(BorderElementContract.lineWidth, on: VStackContract.self),
        .complete(BorderElementContract.stroke, on: VStackContract.self),
        .complete(VisualElementContract.background, on: ZStackContract.self),
        .complete(BorderElementContract.shape, on: ZStackContract.self),
        .complete(BorderElementContract.lineWidth, on: ZStackContract.self),
        .complete(BorderElementContract.stroke, on: ZStackContract.self),
        .partial(BorderElementContract.stroke, on: ScrollViewContract.self,
            missing: "AppKit outlines a scroller in one color: a gradient draws none."),
        .complete(AutomationElementContract.accessibilityIdentifier, on: ZStackContract.self),
        .complete(VisualElementContract.ignoresInput, on: ZStackContract.self),
        .complete(PaddingElementContract.padding, on: ZStackContract.self),
        .complete(VisualElementContract.background, on: FillContract.self),
        .complete(BorderElementContract.shape, on: FillContract.self),
        .complete(BorderElementContract.lineWidth, on: FillContract.self),
        .complete(BorderElementContract.stroke, on: FillContract.self),
        .complete(AutomationElementContract.accessibilityIdentifier, on: FillContract.self),
        .complete(VisualElementContract.ignoresInput, on: FillContract.self),
        .complete(VisualElementContract.background, on: SpaceContract.self),
        .complete(BorderElementContract.shape, on: SpaceContract.self),
        .complete(BorderElementContract.lineWidth, on: SpaceContract.self),
        .complete(BorderElementContract.stroke, on: SpaceContract.self),
        .complete(AutomationElementContract.accessibilityIdentifier, on: SpaceContract.self),
        .complete(VisualElementContract.ignoresInput, on: SpaceContract.self),
        .complete(VisualElementContract.background, on: LayoutEngineContract.self),
        .complete(BorderElementContract.shape, on: LayoutEngineContract.self),
        .complete(BorderElementContract.lineWidth, on: LayoutEngineContract.self),
        .complete(BorderElementContract.stroke, on: LayoutEngineContract.self),
        .complete(AutomationElementContract.accessibilityIdentifier, on: LayoutEngineContract.self),
        .complete(VisualElementContract.ignoresInput, on: LayoutEngineContract.self),
        .complete(LayoutEngineContract.handAxis),
        .complete(LayoutEngineContract.handMoved),
        .complete(LayoutEngineContract.handStepped),
        .complete(LayoutEngineContract.itemDrag),
        .complete(LayoutEngineContract.magnifies),
        .complete(LayoutEngineContract.pans),
        .complete(LayoutEngineContract.rotates),
        .complete(LayoutEngineContract.pinchMoved),
        .complete(LayoutEngineContract.itemMoved),
        .notPlanned(TintElementContract.tint, on: SpinnerContract.self, reason: accentColored),
        .notPlanned(TintElementContract.tint, on: ProgressBarContract.self, reason: accentColored),
        .notPlanned(TintElementContract.tint, on: SwitchContract.self, reason: accentColored),
        .notPlanned(ButtonContract.iconSpacing,
            reason: "AppKit's button stands its picture at its own gap from the words: it takes no other."),
    ] + dayPickers + HostRecord.layoutEngine

    /// Why a progress indicator and a switch take no color of their own.
    private static let accentColored = "AppKit draws it in the accent color the user chooses: it takes none of its own."

    /// What a day's and a time's picker holds none of.
    private static let dayPickers: [HostRecord] = {
        let opens = "AppKit's date picker opens no calendar for the program, nor says when the user opens one."
        let opening: [any ContractMember] = [
            DatePickerContract.isOpen, DatePickerContract.opened, DatePickerContract.closed,
            TimePickerContract.isOpen, TimePickerContract.opened, TimePickerContract.closed,
        ]
        let written = "AppKit's date picker writes its day and time in the user's own way, whatever form is asked."
        return opening.map { member -> HostRecord in .notPlanned(member, reason: opens) } + [
            .notPlanned(DatePickerContract.format, reason: written), .notPlanned(TimePickerContract.format, reason: written),
        ]
    }()

    /// What AppKit's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = AppKitRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames,
            acts: AppKitRegistrations.acts.map(\.name))
    }

    /// What AppKit realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(records: records, unrealized: unrealized, notPlanned: notPlanned).and(declaration)
    }
}
