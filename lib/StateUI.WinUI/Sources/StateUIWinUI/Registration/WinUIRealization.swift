// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What this host realizes beyond its registry, whose export says the rest - the WinUI 3 column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum WinUIRealization {
    /// Realized in full.
    case complete(_ owner: String, _ member: String)

    /// Realized, but incomplete - `missing` says what is not.
    case partial(_ owner: String, _ member: String, missing: String)

    /// Not planned for Windows, which meets the contract there - `reason` says why.
    case notPlanned(_ owner: String, _ member: String, reason: String)

    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: Set<String> = [
        "ActivityIndicator", "Canvas", "CheckBox", "Content", "ContextMenu", "DatePicker", "LeadingContent", "Map",
        "Menu", "MenuBar", "MenuItem", "MenuSeparator", "ModalStack", "Picker", "Pin", "PositionIndicator",
        "ProgressBar", "RadioButton", "SearchField", "Setters", "Stepper", "TextEditor", "TimePicker", "TitleBar",
        "TrailingContent", "VisualState", "WebView",
    ]

    /// The entries this host presents with no view of their own - a span is a run of its label's words - so no
    /// tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["Span"]

    /// The entries Windows will not have; none.
    static let notPlanned: Set<String> = []

    /// Every record, the tiers' first.
    static let records: [WinUIRealization] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "title"),

        // MARK: Entries - a control's or a part's own
        .complete("Page", "appearing"),
        .complete("Page", "disappearing"),
        .complete("Page", "hasNavigationBar"),
        .complete("Page", "navigatedFrom"),
        .complete("Page", "navigatedTo"),
        .complete("Page", "navigatingFrom"),
        .complete("Span", "background"),
        .complete("Span", "fontAttributes"),
        .complete("Span", "fontSize"),
        .complete("Span", "text"),
        .complete("Span", "textColor"),
        .complete("Span", "textDecorations"),
        .complete("SplitView", "isSidebarVisible"),
        .complete("TabbedView", "currentPage"),
        .complete("ToolbarItem", "placement"),
        .complete("ToolbarItem", "priority"),
    ]
}
