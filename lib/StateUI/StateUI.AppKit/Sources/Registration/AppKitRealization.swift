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

    /// Every record, the tiers' first.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete(BarElementContract.barBackgroundColor),
        .partial(BarElementContract.barForegroundColor,
            missing: "Only the title takes it, over a band painted in a bar colour; the toolbar's items keep the system's colour."),
        .complete(BarElementContract.barIcon),
        .complete(BarElementContract.barSubtitle),
        .complete(BarElementContract.barTitle),
        .complete(DecorableTextElementContract.textDecorations),
        .complete(LineHeightElementContract.lineHeight),
        .complete(MenuItemContract.isOn),
        .complete(MenuItemElementContract.keyboardShortcut, on: MenuItemContract.self),
        .complete(MenuItemContract.toggled),
        .complete(MenuItemElementContract.clicked),
        .complete(MenuItemElementContract.icon),
        .complete(MenuItemElementContract.isEnabled),
        .complete(MenuItemElementContract.text),
        .complete(PageElementContract.icon),
        .complete(PageElementContract.title),
        .complete(LayoutContract.clipsContent),
        .partial(VisualElementContract.accessibilityHeading,
            missing: "AppKit marks a heading, not its level: every level is a heading."),
        .partial(TextInputContract.inputPurpose,
            missing: "A Mac has no keyboard on the screen: a purpose sets capitals, spell checking, correction and prediction, no keys."),
        .partial(VisualElementContract.background,
            missing: "AppKit paints a colour on this view; a brush, a blur and glass are drawn only by a layout, and elsewhere a blur's colour stands in."),
        .partial(ViewContract.panTouchCount,
            missing: "The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off."),
        .complete(VisualElementContract.layoutDirection),
        .complete(VisualElementContract.style),
        .notPlanned(FontElementContract.isFontAutoScalingEnabled,
            reason: "macOS gives an application no text size of the user's to follow."),
        .notPlanned(FontElementContract.isFontAutoScalingEnabled, on: TextSpanContract.self,
            reason: "macOS gives an application no text size of the user's to follow."),

        // MARK: Entries - a control's or a part's own, and where it differs from its tier
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
        .complete(ButtonContract.menuKind),
        .complete(PaddingElementContract.padding, on: ButtonContract.self),
        .complete(ButtonContract.showsMenuArrow),
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
        .complete(TextStyleElementContract.textColor, on: TextContract.self),
        .complete(TextContract.verticalTextAlignment),
        .complete(MenuContract.isEnabled),
        .complete(MenuContract.text),
        .complete(MenuBarContract.order),
        .partial(AutomationElementContract.accessibilityIdentifier, on: MenuItemContract.self,
            missing: "Only an entry of a context menu carries it; an entry the page puts in the menu bar does not."),
        .complete(MenuItemElementContract.isDestructive, on: MenuItemContract.self),
        .complete(ModalStackContract.popped),
        .complete(AutomationElementContract.accessibilityIdentifier, on: NavigationStackContract.self),
        .complete(NavigationStackContract.popped),
        .complete(PageContract.appearing),
        .complete(PageContract.backButtonTitle),
        .complete(PageContract.disappearing),
        .complete(PageContract.showsBackButton),
        .complete(PageContract.showsNavigationBar),
        .complete(PageContract.showsTitle),
        // A page is no `VisualElement`: it wears `PageElement` alone, so the
        // tier's record about a background does not reach it.
        .complete(PageContract.background),
        .complete(PageElementContract.icon, on: PageContract.self),
        .complete(PageContract.navigatedFrom),
        .complete(PageContract.navigatedTo),
        .complete(PageContract.navigatingFrom),
        .complete(PageElementContract.title, on: PageContract.self),
        .complete(PickerContract.presentation),
        .complete(RadioButtonContract.groupName),
        .complete(PaddingElementContract.padding, on: RadioButtonContract.self),
        .complete(SceneContract.activated),
        .complete(SceneContract.deactivated),
        .complete(SceneContract.stopped),
        .complete(SceneContract.windowClosed),
        .complete(ScrollViewContract.scrollStopped),
        .complete(ScrollViewContract.scrollXChanged),
        .complete(ScrollViewContract.scrollYChanged),
        .complete(TextSpanContract.background),
        .complete(FontElementContract.fontAttributes, on: TextSpanContract.self),
        .complete(FontElementContract.fontWeight, on: TextSpanContract.self),
        .complete(FontElementContract.textStyle, on: TextSpanContract.self),
        .complete(FontElementContract.fontFamily, on: TextSpanContract.self),
        .complete(FontElementContract.fontSize, on: TextSpanContract.self),
        .complete(TextualElementContract.text, on: TextSpanContract.self),
        .complete(TextualElementContract.textCase, on: TextSpanContract.self),
        .complete(TextStyleElementContract.textColor, on: TextSpanContract.self),
        .complete(DecorableTextElementContract.textDecorations, on: TextSpanContract.self),
        .complete(TrackingElementContract.tracking, on: TextSpanContract.self),
        .complete(SplitViewContract.showsSidebarChanged),
        .complete(SplitViewContract.sidebarOverlays),
        .notPlanned(SplitViewContract.flyoutBackground,
            reason: "A Mac sidebar always stands beside the detail: a window too narrow for both hides it."),
        .complete(AutomationElementContract.accessibilityIdentifier, on: TabViewContract.self),
        .complete(TabViewContract.selectedTab),
        .complete(TabViewContract.selectedTabChanged),
        .complete(MenuItemElementContract.keyboardShortcut, on: ToolbarItemContract.self),
        .complete(ToolbarItemContract.placement),
        .notPlanned(ToolbarItemContract.showsText,
            reason: "A Mac shows a toolbar's words as its user sets the whole toolbar, not item by item."),
        .unrealized(AutomationElementContract.accessibilityIdentifier, on: ToolbarItemContract.self,
            why: "An NSToolbarItem holds no accessibility identifier."),
        .complete(ToolbarItemGroupContract.order),
        .complete(ToolbarItemGroupContract.side),
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
            missing: "AppKit outlines a scroller in one colour: a gradient draws none."),
        .complete(AutomationElementContract.accessibilityIdentifier, on: ZStackContract.self),
        .complete(VisualElementContract.ignoresInput, on: ZStackContract.self),
        .complete(PaddingElementContract.padding, on: ZStackContract.self),
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
        .notPlanned(TintElementContract.tint, on: ActivityIndicatorContract.self, reason: accentColoured),
        .notPlanned(TintElementContract.tint, on: ProgressBarContract.self, reason: accentColoured),
        .notPlanned(TintElementContract.tint, on: SwitchContract.self, reason: accentColoured),
        .notPlanned(ButtonContract.iconSpacing,
            reason: "AppKit's button stands its picture at its own gap from the words: it takes no other."),
    ] + dayPickers + HostRecord.layoutEngine

    /// Why a progress indicator and a switch take no colour of their own.
    private static let accentColoured = "AppKit draws it in the accent colour the user chooses: it takes none of its own."

    /// What a day's and a time's picker holds none of.
    private static let dayPickers: [HostRecord] = {
        let opens = "AppKit's date picker opens no calendar for the program, nor says when the user opens one."
        let opening: [any ContractMember] = [
            DatePickerContract.isOpen, DatePickerContract.opened, DatePickerContract.closed,
            TimePickerContract.isOpen, TimePickerContract.opened, TimePickerContract.closed,
        ]
        let written = "AppKit's date picker writes its day and time in the user's own way: it takes no pattern."
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
