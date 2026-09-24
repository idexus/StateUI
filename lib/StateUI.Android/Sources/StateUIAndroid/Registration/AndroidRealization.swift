// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What this host realizes beyond its registry - the pages, the lifecycle, a label's runs - member by
/// member, for the Android Views column of the control dictionary, `docs/controls/`.
///
/// The registry says the rest itself: `exports/android.bin`, written by this package's suite. A record
/// names an entry of the dictionary or a tier; an entry's own record wins over its tier's. A member is
/// recorded once this host realizes it and a test of this package covers it; `.partial` says what is
/// still missing. `ControlDictionaryTests`, in the core's suite, reads these records as text.
enum AndroidRealization {
    /// Realized in full.
    case complete(_ owner: String, _ member: String)

    /// Realized, but incomplete - `missing` says what is not.
    case partial(_ owner: String, _ member: String, missing: String)

    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: Set<String> = [
        "Content", "LeadingContent", "Map", "MenuBar", "Overlay", "Pin", "PositionIndicator", "RefreshView",
        "Setters", "SwipeAction", "SwipeActions", "SwipeView", "TitleBar", "TrailingContent",
        "VisualState", "WebView",
    ]

    /// The entries this host presents with no view of their own - a span is a run of its label's text - so
    /// no tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["Span"]

    /// Every record, the tiers' first.
    static let records: [AndroidRealization] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "isDestructive"),
        .complete("MenuItemElement", "isEnabled"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "icon"),
        .complete("PageElement", "title"),

        // MARK: Entries - a control's or a part's own
        .partial("Button", "aspect", missing: "Android's button has no covering scale: `.fill` fits the icon, as `.fit` does."),
        .complete("Menu", "isEnabled"),
        .complete("Menu", "text"),
        .complete("NavigationStack", "popped"),
        .complete("Page", "appearing"),
        .complete("Page", "disappearing"),
        .complete("Page", "navigatedFrom"),
        .complete("Page", "navigatedTo"),
        .complete("Page", "navigatingFrom"),
        .partial("Picker", "isOpen", missing: "Android closes the list only when the user does: `false` does not close it."),
        .complete("RadioButton", "groupName"),
        .complete("Scene", "activated"),
        .complete("Scene", "deactivated"),
        .complete("Scene", "stopped"),
        .complete("Span", "fontSize"),
        .complete("Span", "text"),
        .complete("SplitView", "isSidebarVisibleChanged"),
        .complete("TabbedView", "currentPage"),
        .complete("TabbedView", "currentPageChanged"),
        .complete("ToolbarItem", "icon"),
        .complete("ToolbarItem", "placement"),
        .complete("ToolbarItem", "priority"),
        .complete("Window", "activated"),
        .complete("Window", "deactivated"),
        .complete("Window", "modalPopped"),
        .complete("Window", "stopped"),
    ]
}
