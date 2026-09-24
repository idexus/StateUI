// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What this host realizes, member by member - the AppKit column of the
/// control dictionary, `docs/controls/`.
///
/// A record names an entry of the dictionary - a control, or a part of an
/// application's structure - or a tier, the protocol an entry takes the member
/// from; an entry's own record wins over its tier's. A member is recorded once
/// this host realizes it and a test of this package covers it; `.partial` says
/// what is still missing; an act is recorded where a test of this package
/// performs it. `ControlDictionaryTests`, in the core's suite, reads these
/// records, holds each to the contracts, and renders the dictionary's AppKit
/// column from them.
enum AppKitRealization {
    /// Realized in full.
    case complete(_ owner: String, _ member: String)

    /// Realized, but incomplete - `missing` says what is not.
    case partial(_ owner: String, _ member: String, missing: String)

    /// The entry or tier the record is about.
    var owner: String {
        switch self {
        case .complete(let owner, _), .partial(let owner, _, _):
            return owner
        }
    }

    /// The member the record is about - a property, or a handler's event.
    var member: String {
        switch self {
        case .complete(_, let member), .partial(_, let member, _):
            return member
        }
    }

    /// The entries this host realizes none of: those it shows as unsupported,
    /// `AppKitUnsupportedView`, the parts of one, and a style's setters and
    /// visual states, which it has no handling of.
    static let unrealized: Set<String> = [
        "Map", "Pin", "PositionIndicator", "Setters", "VisualState", "WebView",
    ]

    /// The entries this host presents with no view of their own - a title
    /// bar is the window's, a span a run of its label's text - so no tier's
    /// record reaches them: only a member the entry's own records name is
    /// realized.
    static let viewless: Set<String> = ["Span", "TitleBar"]

    /// Every record, the tiers' first.
    static let records: [AppKitRealization] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("BarElement", "barBackgroundColor"),
        .complete("DecorableTextElement", "textDecorations"),
        .complete("LineHeightElement", "lineHeight"),
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "icon"),
        .complete("MenuItemElement", "isEnabled"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "icon"),
        .complete("PageElement", "title"),
        .partial("VisualElement", "background", missing: "AppKit paints a colour on this view; a brush is drawn only by `Border`."),
        .partial("Shape", "stroke", missing: "AppKit strokes with a colour; a gradient brush draws no outline."),
        .partial("View", "panTouchCount", missing: "AppKit recognises a one-finger pan only; any other `panTouchCount` turns the pan off."),

        // MARK: Entries - a control's or a part's own, and where it differs from its tier
        .complete("Border", "accessibilityIdentifier"),
        .complete("Border", "background"),
        .complete("Border", "ignoresInput"),
        .complete("Border", "padding"),
        .complete("Border", "shape"),
        .partial("Border", "stroke", missing: "AppKit strokes with a colour; a gradient brush draws no outline."),
        .complete("Border", "strokeWidth"),
        .partial("Button", "aspect", missing: "AppKit's button has no covering scale: `.fill` fits the icon, as `.fit` does."),
        .complete("Button", "padding"),
        .complete("Label", "accessibilityIdentifier"),
        .complete("Label", "characterSpacing"),
        .complete("Label", "fontAttributes"),
        .complete("Label", "fontFamily"),
        .complete("Label", "fontSize"),
        .complete("Label", "horizontalTextAlignment"),
        .complete("Label", "ignoresInput"),
        .complete("Label", "lineBreak"),
        .complete("Label", "maximumLines"),
        .complete("Label", "padding"),
        .complete("Label", "textCase"),
        .complete("Label", "textColor"),
        .complete("Label", "verticalTextAlignment"),
        .complete("Menu", "isEnabled"),
        .complete("Menu", "text"),
        .partial("MenuItem", "accessibilityIdentifier", missing: "Only an entry of a context menu carries it; an entry the page puts in the menu bar does not."),
        .complete("MenuItem", "isDestructive"),
        .complete("NavigationStack", "accessibilityIdentifier"),
        .complete("NavigationStack", "barForegroundColor"),
        .complete("NavigationStack", "popped"),
        .complete("Page", "appearing"),
        .complete("Page", "backButtonTitle"),
        .complete("Page", "disappearing"),
        .complete("Page", "hasBackButton"),
        .complete("Page", "hasNavigationBar"),
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
        .complete("Scene", "destroying"),
        .complete("Scene", "stopped"),
        .complete("Scene", "windowClosed"),
        .complete("Scene", "windowRestored"),
        .complete("ScrollView", "scrollStopped"),
        .complete("ScrollView", "scrollXChanged"),
        .complete("ScrollView", "scrollYChanged"),
        .complete("Span", "fontAttributes"),
        .complete("Span", "text"),
        .complete("Span", "textCase"),
        .complete("SplitView", "isSidebarVisibleChanged"),
        .complete("TabbedView", "accessibilityIdentifier"),
        .complete("TabbedView", "currentPage"),
        .complete("TabbedView", "currentPageChanged"),
        .partial("TitleBar", "background", missing: "AppKit paints a colour on the window's bar band; a brush is drawn only by `Border`."),
        .complete("TitleBar", "barForegroundColor"),
        .complete("TitleBar", "icon"),
        .complete("TitleBar", "subtitle"),
        .complete("TitleBar", "title"),
        .complete("ToolbarItem", "placement"),
        .complete("ToolbarItem", "priority"),
        .complete("Window", "activated"),
        .complete("Window", "created"),
        .complete("Window", "deactivated"),
        .complete("Window", "destroying"),
        .complete("Window", "floatsOnTop"),
        .complete("Window", "height"),
        .complete("Window", "hidesWhenInactive"),
        .complete("Window", "isMaximizable"),
        .complete("Window", "isMinimizable"),
        .complete("Window", "isTranslucent"),
        .complete("Window", "maximumHeight"),
        .complete("Window", "maximumWidth"),
        .complete("Window", "minimumHeight"),
        .complete("Window", "minimumWidth"),
        .complete("Window", "modalPopped"),
        .complete("Window", "resumed"),
        .complete("Window", "stopped"),
        .complete("Window", "title"),
        .complete("Window", "width"),
        .complete("Window", "windowType"),
        .complete("Window", "windowValue"),
        .complete("Window", "x"),
        .complete("Window", "y"),
        .complete("ZStack", "accessibilityIdentifier"),
        .complete("ZStack", "ignoresInput"),
        .complete("ZStack", "padding"),
    ]
}
