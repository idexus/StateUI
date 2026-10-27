// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple

/// What this host realizes beyond its registry, whose export says the rest - the UIKit column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum UIKitRealization {
    /// The entries this host realizes none of yet: it shows each one's name in red where it belongs.
    static let unrealized: [any ElementContract.Type] = []

    /// The entries an iPhone and an iPad will not have; none.
    static let notPlanned: [(any ElementContract.Type, reason: String)] = []

    /// Why a reader's steps reach no element UIKit shows through a view of its own.
    static let ownSteps = "VoiceOver meets UIKit's own view here - a control, a list, a map, a page - which steps "
        + "as its own kind does, or not at all; a view StateUI draws takes a reader's steps."

    /// What UIKit's glass cannot be, as it is shaped by its corners alone.
    private static let ovalGlass = "UIKit's glass is shaped by its corners alone: an oval of two lengths stands on "
        + "the blur as clear as the glass is."

    /// Every record, beside what the registry's export says.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete(BarElementContract.barBackground),
        .notPlanned(BarElementContract.barButtonBackgroundColor, reason: "A bar button stands in the system's glass, which takes no color of the application's."),
        .notPlanned(BarElementContract.toolbarStyle, reason: "The bar's buttons keep iOS's own look."),
        .complete(BarElementContract.barButtonFontWeight),
        .complete(BarElementContract.barForegroundColor),
        .complete(ButtonContract.keyboardShortcut),
        .complete(ButtonMenuElementContract.menuKind, on: ButtonContract.self),
        .partial(ButtonMenuElementContract.menuKind, on: ToolbarButtonContract.self,
            missing: "UIKit's bar offers no arrow part: a split bar button opens its menu held."),
        .complete(ButtonMenuElementContract.showsMenuArrow, on: ButtonContract.self),
        .complete(TextAndIconElementContract.showsText, on: ButtonContract.self),
        .notPlanned(ButtonMenuElementContract.showsMenuArrow, on: ToolbarButtonContract.self,
            reason: "A UIKit bar button shows no arrow: its menu opens from its tap or its hold."),
        .complete(ButtonContract.role),
        .complete(MenuToggleContract.isOn),
        .partial(MenuItemElementContract.keyboardShortcut, on: MenuItemContract.self,
            missing: "UIKit shows a shortcut in the main menu alone, none in a context menu."),
        .partial(MenuItemElementContract.keyboardShortcut, on: MenuToggleContract.self,
            missing: "UIKit shows a shortcut in the main menu alone, none in a context menu."),
        .complete(MenuToggleContract.toggled),
        .complete(ActionElementContract.clicked),
        .complete(MenuItemElementContract.icon),
        .complete(MenuItemElementContract.isEnabled),
        .complete(MenuItemElementContract.text),
        .complete(PageElementContract.icon),
        .complete(PageElementContract.title),
        .partial(VisualElementContract.accessibilityHeading,
            missing: "UIKit marks a heading, not its level: every level is a heading."),
        .partial(FilledShapeContract.fill, missing: "UIKit's glass is shaped by its corners alone: an oval of two "
            + "lengths, a figure of its own and a turned one are made of the blur as clear as the glass is."),
        .partial(VisualElementContract.background,
            missing: "UIKit paints a color on this view; a brush, a blur and glass are drawn only by a layout, and elsewhere a blur's color stands in."),
        .complete(VisualElementContract.ignoresInput),
        .complete(VisualElementContract.layoutDirection),
        .complete(VisualElementContract.style),

        // MARK: Entries - a control's or a part's own
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: SpinnerContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: ButtonContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: LinkContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: CheckBoxContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: ColorPickerContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: DatePickerContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: SeparatorContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: ItemsViewContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: MapContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: PickerContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: ProgressBarContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: SearchFieldContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: SliderContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: StepperContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: SwitchContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: TextEditorContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: TextFieldContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: TimePickerContract.self, reason: Self.ownSteps),
        .notPlanned(VisualElementContract.accessibilityAdjusted, on: WebViewContract.self, reason: Self.ownSteps),
        .complete(PopoverContract.isPresented),
        .complete(PopoverContract.isPresentedChanged),
        .complete(VisualElementContract.background, on: ButtonContract.self),
        .notPlanned(VisualElementContract.background, on: DatePickerContract.self,
            reason: "UIKit's date picker keeps no background color: one written reads back as none."),
        .partial(VisualElementContract.background, on: GridContract.self, missing: Self.ovalGlass),
        .partial(VisualElementContract.background, on: HStackContract.self, missing: Self.ovalGlass),
        .partial(VisualElementContract.background, on: ScrollViewContract.self, missing: Self.ovalGlass),
        .complete(VisualElementContract.background, on: TextContract.self),
        .notPlanned(VisualElementContract.background, on: TimePickerContract.self,
            reason: "UIKit's time picker keeps no background color: one written reads back as none."),
        .partial(VisualElementContract.background, on: VStackContract.self, missing: Self.ovalGlass),
        .partial(VisualElementContract.background, on: ZStackContract.self, missing: Self.ovalGlass),
        .partial(VisualElementContract.background, on: FillContract.self, missing: Self.ovalGlass),
        .partial(VisualElementContract.background, on: SpaceContract.self, missing: Self.ovalGlass),
        .partial(VisualElementContract.background, on: PhaseLayoutContract.self, missing: Self.ovalGlass),
        .complete(PhaseLayoutContract.handAxis),
        .complete(PhaseLayoutContract.handMoved),
        .complete(PhaseLayoutContract.handStepped),
        .complete(PhaseLayoutContract.itemDrag),
        .complete(PhaseLayoutContract.itemMoved),
        .complete(PhaseLayoutContract.magnifies),
        .complete(PhaseLayoutContract.pans),
        .complete(PhaseLayoutContract.rotates),
        .complete(PhaseLayoutContract.pinchMoved),
        .unrealized(VisualElementContract.style, on: ItemsViewContract.self,
            why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .partial(MenuContract.isEnabled, missing: "UIKit holds no menu out of reach itself: each of its entries is."),
        .partial(LayoutContract.ignoresSafeArea, missing: "UIKit lets a page's own layout under the bars and the notch; "
            + "a layout deeper in stands where its page puts it, and the safe area holds no keyboard."),
        .partial(ViewContract.panTouchCount,
            missing: "The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off."),
        .complete(MenuContract.text),
        .complete(MenuBarContract.order),
        .complete(SheetContract.isPresented),
        .complete(SheetContract.isPresentedChanged),
        .complete(ActionElementContract.role, on: MenuItemContract.self),
        .complete(NavigationStackContract.popped),
        .complete(PageContract.appearing),
        .complete(PageContract.backButtonTitle),
        .complete(PageElementContract.background),
        .complete(PageElementContract.linkOpened),
        .complete(PageContract.disappearing),
        .complete(PageContract.showsBackButton),
        .complete(PageContract.showsCloseButton),
        .complete(PageContract.showsNavigationBar),
        .complete(PageContract.showsTitle),
        .complete(PageContract.subtitle),
        .complete(PageElementContract.icon, on: PageContract.self),
        .complete(PageContract.navigatedFrom),
        .complete(PageContract.navigatedTo),
        .complete(PageContract.navigatingFrom),
        .complete(PageElementContract.title, on: PageContract.self),
        .partial(PickerContract.presentation,
            missing: "UIKit has no radio buttons: `.radio` is a column of its buttons, "
            + "each marked by a filled or an empty circle."),
        .complete(SceneContract.activated),
        .complete(SceneContract.deactivated),
        .complete(SceneContract.stopped),
        .complete(SceneContract.windowClosed),
        .complete(TextContract.isSelectable),
        .complete(TextSpanContract.background),
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
        .complete(SplitViewContract.showsSidebar),
        .complete(SplitViewContract.showsSidebarChanged),
        .complete(SplitViewContract.showsSidebarToggle),
        .complete(SplitViewContract.sidebarBackground),
        .complete(SplitViewContract.sidebarOverlayBackground),
        .complete(SplitViewContract.sidebarOverlays),
        .complete(TabViewContract.selectedTab),
        .complete(TabViewContract.selectedTabChanged),
        .complete(ActionElementContract.role, on: ToolbarButtonContract.self),
        .complete(MenuItemElementContract.keyboardShortcut, on: ToolbarButtonContract.self),
        .notPlanned(TextAndIconElementContract.showsText, on: ToolbarButtonContract.self,
            reason: "A UIKit bar button shows its picture or its words, never both."),
        .complete(MenuItemElementContract.keyboardShortcut, on: ToolbarToggleContract.self),
        .complete(ToolbarToggleContract.isOn),
        .complete(ToolbarToggleContract.onIcon),
        .notPlanned(TextAndIconElementContract.showsText, on: ToolbarToggleContract.self,
            reason: "A UIKit bar button shows its picture or its words, never both."),
        .complete(ToolbarToggleContract.toggled),
        .complete(ToolbarGroupContract.order),
        .complete(ToolbarGroupContract.part),
        .complete(ToolbarGroupContract.hidesWithSidebar),
        .complete(ToolbarGroupContract.isEnabled),
        .complete(ToolbarGroupContract.position),
        .notPlanned(VisualElementContract.tooltip,
            reason: "UIKit shows a tool tip on the Mac and on visionOS only: an iPhone and an iPad show none."),
        .complete(WindowContract.activated),
        .complete(WindowContract.created),
        .complete(WindowContract.deactivated),
        .complete(WindowContract.destroying),
        .notPlanned(WindowContract.floatsOnTop,
            reason: "iPadOS stacks its windows itself: UIKit keeps none above the others."),
        .notPlanned(WindowContract.height, reason: Self.sizedBySystem),
        .notPlanned(WindowContract.hidesWhenInactive,
            reason: "iPadOS shows an application's windows itself: UIKit hides none while another is in front."),
        .notPlanned(WindowContract.isMaximizable,
            reason: "Any iPadOS window may fill the screen: UIKit keeps none from it."),
        .notPlanned(WindowContract.isMinimizable,
            reason: "Any iPadOS window may be put away: UIKit keeps none from it."),
        .partial(WindowContract.background,
            missing: "iPadOS draws an application's window opaque: a blur or glass shows its color."),
        .complete(WindowContract.resumed),
        .complete(WindowContract.stopped),
        .complete(WindowContract.title),
        .notPlanned(WindowContract.width, reason: Self.sizedBySystem),
        .notPlanned(WindowContract.x, reason: Self.placedBySystem),
        .notPlanned(WindowContract.y, reason: Self.placedBySystem),
    ] + pickerWords + HostRecord.phaseLayout

    /// Why a window takes no size: the user's hand gives it, and a scene asks only for orientations.
    private static let sizedBySystem =
        "iPadOS sizes its windows itself - the user drags a corner: a UIKit scene asks for no size."

    /// Why a window takes no place.
    private static let placedBySystem = "iPadOS places its windows itself: a UIKit scene asks for no place."

    /// The words of a day's and a time's picker, which UIKit draws in its own look.
    private static let pickerWords: [HostRecord] = {
        let pickers: [any ElementContract.Type] = [DatePickerContract.self, TimePickerContract.self]
        let words: [any ContractMember] = [
            FontElementContract.fontAttributes, FontElementContract.fontFamily, FontElementContract.fontSize,
            FontElementContract.fontWeight, TextColorElementContract.textColor, FontElementContract.textStyle,
        ]
        return pickers.flatMap { picker -> [HostRecord] in
            words.map { member -> HostRecord in
                .notPlanned(member, on: picker,
                    reason: "UIKit's date picker draws its words in its own font and color: it takes neither.")
            } + [
                .notPlanned(FontElementContract.isFontAutoScalingEnabled, on: picker,
                    reason: "UIKit's date picker draws its words in its own font, which follows the user's text size always."),
            ]
        }
    }()

    /// What UIKit's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = UIKitRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames,
            acts: (HostActs.performed + HostActs.files + HostActs.network + WebKitView.acts
                + UIKitRegistrations.itemsActs + [MapContract.moveToRegion]).map(\.name))
    }

    /// What UIKit realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(records: records, unrealized: unrealized, notPlanned: notPlanned).and(declaration)
    }
}
#endif
