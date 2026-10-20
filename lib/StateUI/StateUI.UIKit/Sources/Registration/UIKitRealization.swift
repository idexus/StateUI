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

    /// Every record, beside what the registry's export says.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete(BarElementContract.barBackgroundColor),
        .complete(BarElementContract.barForegroundColor),
        .notPlanned(BarElementContract.barIcon,
            reason: "A UIKit bar is each page's own: it shows that page's title, and no application's mark."),
        .complete(BarElementContract.barSubtitle),
        .notPlanned(BarElementContract.barTitle,
            reason: "A UIKit bar is each page's own and names that page; an application names itself in none."),
        .complete(ButtonContract.keyboardShortcut),
        .complete(ButtonContract.menuKind),
        .complete(ButtonContract.showsMenuArrow),
        .complete(ButtonContract.role),
        .complete(MenuItemContract.isOn),
        .partial(MenuItemElementContract.keyboardShortcut, on: MenuItemContract.self,
            missing: "UIKit shows a shortcut in the main menu alone, none in a context menu."),
        .complete(MenuItemContract.toggled),
        .complete(MenuItemElementContract.clicked),
        .complete(MenuItemElementContract.icon),
        .complete(MenuItemElementContract.isEnabled),
        .complete(MenuItemElementContract.text),
        .complete(PageElementContract.icon),
        .complete(PageElementContract.title),
        .partial(VisualElementContract.accessibilityHeading,
            missing: "UIKit marks a heading, not its level: every level is a heading."),
        .partial(VisualElementContract.background,
            missing: "UIKit paints a colour on this view; a brush, a blur and glass are drawn only by a layout, and elsewhere a blur's colour stands in."),
        .complete(VisualElementContract.ignoresInput),
        .complete(VisualElementContract.layoutDirection),
        .complete(VisualElementContract.style),

        // MARK: Entries - a control's or a part's own
        .complete(VisualElementContract.background, on: ButtonContract.self),
        .notPlanned(VisualElementContract.background, on: DatePickerContract.self,
            reason: "UIKit's date picker keeps no background colour: one written reads back as none."),
        .complete(VisualElementContract.background, on: GridContract.self),
        .complete(VisualElementContract.background, on: HStackContract.self),
        .complete(VisualElementContract.background, on: ScrollViewContract.self),
        .complete(VisualElementContract.background, on: TextContract.self),
        .notPlanned(VisualElementContract.background, on: TimePickerContract.self,
            reason: "UIKit's time picker keeps no background colour: one written reads back as none."),
        .complete(VisualElementContract.background, on: VStackContract.self),
        .complete(VisualElementContract.background, on: ZStackContract.self),
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
        .unrealized(VisualElementContract.style, on: ItemsViewContract.self,
            why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .partial(MenuContract.isEnabled, missing: "UIKit holds no menu out of reach itself: each of its entries is."),
        .partial(LayoutContract.avoidsSafeArea, missing: "UIKit lets a page's own layout under the bars and the notch; "
            + "a layout deeper in stands where its page puts it, and none stands clear of the keyboard."),
        .partial(ViewContract.panTouchCount,
            missing: "The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off."),
        .complete(MenuContract.text),
        .complete(MenuBarContract.order),
        .complete(ModalStackContract.popped),
        .complete(MenuItemElementContract.role, on: MenuItemContract.self),
        .complete(NavigationStackContract.popped),
        .complete(PageContract.appearing),
        .complete(PageContract.backButtonTitle),
        .complete(PageContract.background),
        .complete(PageContract.disappearing),
        .complete(PageContract.showsBackButton),
        .complete(PageContract.showsNavigationBar),
        .complete(PageContract.showsTitle),
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
        .complete(SplitViewContract.sidebarBackground),
        .complete(SplitViewContract.flyoutBackground),
        .complete(SplitViewContract.sidebarOverlays),
        .complete(TabViewContract.selectedTab),
        .complete(TabViewContract.selectedTabChanged),
        .complete(MenuItemElementContract.role, on: ToolbarItemContract.self),
        .complete(MenuItemElementContract.keyboardShortcut, on: ToolbarItemContract.self),
        .complete(ToolbarItemContract.placement),
        .notPlanned(ToolbarItemContract.showsText,
            reason: "A UIKit bar button shows its picture or its words, never both."),
        .complete(ToolbarItemGroupContract.order),
        .complete(ToolbarItemGroupContract.side),
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
            missing: "iPadOS draws an application's window opaque: a blur or glass shows its colour."),
        .complete(WindowContract.resumed),
        .complete(WindowContract.stopped),
        .complete(WindowContract.title),
        .notPlanned(WindowContract.width, reason: Self.sizedBySystem),
        .notPlanned(WindowContract.x, reason: Self.placedBySystem),
        .notPlanned(WindowContract.y, reason: Self.placedBySystem),
    ] + pickerWords + HostRecord.layoutEngine

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
                    reason: "UIKit's date picker draws its words in its own font and colour: it takes neither.")
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
            acts: (HostActs.performed + HostActs.files + WebKitView.acts + UIKitRegistrations.itemsActs
                + [MapContract.moveToRegion]).map(\.name))
    }

    /// What UIKit realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(records: records, unrealized: unrealized, notPlanned: notPlanned).and(declaration)
    }
}
#endif
