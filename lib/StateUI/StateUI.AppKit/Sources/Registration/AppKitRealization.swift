// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the AppKit column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum AppKitRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: Set<String> = []

    /// The entries this host presents with no view of their own - a span is a run of its label's words - so no
    /// tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["TextSpan"]

    /// The entries the Mac will not have; none.
    static let notPlanned: [String: String] = [:]

    /// Every record, the tiers' first.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("BarElement", "barBackgroundColor"),
        .partial("BarElement", "barForegroundColor", missing: "Only the title takes it, over a band painted in a bar colour; the toolbar's items keep the system's colour."),
        .complete("BarElement", "barIcon"),
        .complete("BarElement", "barSubtitle"),
        .complete("BarElement", "barTitle"),
        .complete("DecorableTextElement", "textDecorations"),
        .complete("LineHeightElement", "lineHeight"),
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "icon"),
        .complete("MenuItemElement", "isEnabled"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "icon"),
        .complete("PageElement", "title"),
        .complete("Layout", "clipsContent"),
        .partial("VisualElement", "accessibilityHeading", missing: "AppKit marks a heading, not its level: every level is a heading."),
        .partial("TextInput", "inputPurpose", missing: "A Mac has no keyboard on the screen: a purpose sets capitals, spell checking, correction and prediction, no keys."),
        .partial("VisualElement", "background", missing: "AppKit paints a colour on this view; a brush, a blur and glass are drawn only by a layout, and elsewhere a blur's colour stands in."),
        .partial("View", "panTouchCount", missing: "The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off."),
        .complete("VisualElement", "layoutDirection"),
        .complete("VisualElement", "style"),
        .notPlanned("FontElement", "isFontAutoScalingEnabled",
                    reason: "macOS gives an application no text size of the user's to follow."),

        // MARK: Entries - a control's or a part's own, and where it differs from its tier
        .notPlanned("TextField", "submitLabel", reason: "A Mac has no keyboard on the screen whose return key says anything."),
        .notPlanned("SearchField", "submitLabel", reason: "A Mac has no keyboard on the screen whose return key says anything."),
        .notPlanned("TextField", "showsClearButton", reason: "AppKit's text field has no button of its own that empties it."),
        .unrealized("ItemsView", "style", why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .partial("Button", "contentMode", missing: "AppKit's button has no covering scale: `.fill` fits the icon, as `.fit` does."),
        .complete("Button", "padding"),
        .partial("Button", "shape", missing: "AppKit rounds an oval button into a capsule: a layer's corners draw no oval."),
        .complete("Text", "accessibilityIdentifier"),
        .complete("Text", "tracking"),
        .complete("Text", "fontAttributes"),
        .complete("Text", "fontFamily"),
        .complete("Text", "fontSize"),
        .complete("Text", "horizontalTextAlignment"),
        .complete("Text", "ignoresInput"),
        .complete("Text", "lineBreak"),
        .complete("Text", "maximumLines"),
        .complete("Text", "padding"),
        .complete("Text", "textCase"),
        .complete("Text", "textColor"),
        .complete("Text", "verticalTextAlignment"),
        .complete("Menu", "isEnabled"),
        .complete("Menu", "text"),
        .complete("MenuBar", "order"),
        .partial("MenuItem", "accessibilityIdentifier", missing: "Only an entry of a context menu carries it; an entry the page puts in the menu bar does not."),
        .complete("MenuItem", "isDestructive"),
        .complete("ModalStack", "popped"),
        .complete("NavigationStack", "accessibilityIdentifier"),
        .complete("NavigationStack", "popped"),
        .complete("Page", "appearing"),
        .complete("Page", "backButtonTitle"),
        .complete("Page", "disappearing"),
        .complete("Page", "showsBackButton"),
        .complete("Page", "showsNavigationBar"),
        // A page is no `VisualElement`: it wears `PageElement` alone, so the
        // tier's record about a background does not reach it.
        .complete("Page", "background"),
        .complete("Page", "icon"),
        .complete("Page", "navigatedFrom"),
        .complete("Page", "navigatedTo"),
        .complete("Page", "navigatingFrom"),
        .complete("Page", "title"),
        .complete("RadioButton", "groupName"),
        .complete("RadioButton", "padding"),
        .complete("Scene", "activated"),
        .complete("Scene", "deactivated"),
        .complete("Scene", "stopped"),
        .complete("Scene", "windowClosed"),
        .complete("ScrollView", "scrollStopped"),
        .complete("ScrollView", "scrollXChanged"),
        .complete("ScrollView", "scrollYChanged"),
        .complete("TextSpan", "background"),
        .complete("TextSpan", "fontAttributes"),
        .complete("TextSpan", "fontFamily"),
        .complete("TextSpan", "fontSize"),
        .complete("TextSpan", "text"),
        .complete("TextSpan", "textCase"),
        .complete("TextSpan", "textColor"),
        .complete("TextSpan", "textDecorations"),
        .complete("TextSpan", "tracking"),
        .complete("SplitView", "showsSidebarChanged"),
        .complete("TabView", "accessibilityIdentifier"),
        .complete("TabView", "selectedTab"),
        .complete("TabView", "selectedTabChanged"),
        .complete("ToolbarItem", "placement"),
        .notPlanned("ToolbarItem", "showsText",
                    reason: "A Mac shows a toolbar's words as its user sets the whole toolbar, not item by item."),
        .unrealized("ToolbarItem", "accessibilityIdentifier", why: "An NSToolbarItem holds no accessibility identifier."),
        .complete("ToolbarItemGroup", "order"),
        .complete("ToolbarItemGroup", "side"),
        .complete("Window", "activated"),
        .partial("Window", "background", missing: "A window's glass is drawn as the blur as clear as it is."),
        .complete("Window", "created"),
        .complete("Window", "deactivated"),
        .complete("Window", "destroying"),
        .complete("Window", "floatsOnTop"),
        .complete("Window", "height"),
        .complete("Window", "hidesWhenInactive"),
        .complete("Window", "isMaximizable"),
        .complete("Window", "isMinimizable"),
        .complete("Window", "maximumHeight"),
        .complete("Window", "maximumWidth"),
        .complete("Window", "minimumHeight"),
        .complete("Window", "minimumWidth"),
        .complete("Window", "resumed"),
        .complete("Window", "stopped"),
        .complete("Window", "title"),
        .complete("Window", "width"),
        .complete("Window", "windowType"),
        .complete("Window", "windowValue"),
        .complete("Window", "x"),
        .complete("Window", "y"),
        .complete("Grid", "background"),
        .complete("Grid", "shape"),
        .complete("Grid", "lineWidth"),
        .complete("Grid", "stroke"),
        .complete("HStack", "background"),
        .complete("HStack", "shape"),
        .complete("HStack", "lineWidth"),
        .complete("HStack", "stroke"),
        .complete("VStack", "background"),
        .complete("VStack", "shape"),
        .complete("VStack", "lineWidth"),
        .complete("VStack", "stroke"),
        .complete("ZStack", "background"),
        .complete("ZStack", "shape"),
        .complete("ZStack", "lineWidth"),
        .complete("ZStack", "stroke"),
        .partial("ScrollView", "stroke", missing: "AppKit outlines a scroller in a colour on a rectangle or a rounded one; an oval, or a gradient, draws none."),
        .complete("ZStack", "accessibilityIdentifier"),
        .complete("ZStack", "ignoresInput"),
        .complete("ZStack", "padding"),
        .notPlanned("ActivityIndicator", "tint", reason: accentColoured),
        .notPlanned("ProgressBar", "tint", reason: accentColoured),
        .notPlanned("Switch", "tint", reason: accentColoured),
        .notPlanned("Button", "iconSpacing",
                    reason: "AppKit's button stands its picture at its own gap from the words: it takes no other."),
    ] + dayPickers

    /// Why a progress indicator and a switch take no colour of their own.
    private static let accentColoured = "AppKit draws it in the accent colour the user chooses: it takes none of its own."

    /// What a day's and a time's picker holds none of.
    private static let dayPickers: [HostRecord] = ["DatePicker", "TimePicker"].flatMap { picker -> [HostRecord] in
        let opens = "AppKit's date picker opens no calendar for the program, nor says when the user opens one."
        return ["isOpen", "opened", "closed"].map { .notPlanned(picker, $0, reason: opens) } + [
            .notPlanned(picker, "format", reason: "AppKit's date picker writes its day and time in the user's own way: it takes no pattern."),
        ]
    }

    /// What AppKit's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = AppKitRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames,
            acts: AppKitRegistrations.acts.map(\.name))
    }

    /// What AppKit realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(records: records, unrealized: unrealized, viewless: viewless, notPlanned: notPlanned).and(declaration)
    }
}
