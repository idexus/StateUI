// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the UIKit column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum UIKitRealization {
    /// The entries this host realizes none of yet: it shows each one's name in red where it belongs.
    static let unrealized: Set<String> = [
        "Canvas", "Content", "LeadingContent", "Map",
        "Pin", "PositionIndicator",
        "TitleBar", "TrailingContent",
        "WebView",
    ]

    /// The entries this host presents with no view of their own - a span is a run of its label's words - so no
    /// tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["Span"]

    /// Every record, beside what the registry's export says.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("BarElement", "barBackgroundColor"),
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "icon"),
        .complete("MenuItemElement", "isEnabled"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "icon"),
        .complete("PageElement", "title"),

        // MARK: Entries - a control's or a part's own
        .partial("Menu", "isEnabled", missing: "UIKit holds no menu out of reach itself: each of its entries is."),
        .complete("Menu", "text"),
        .complete("MenuItem", "isDestructive"),
        .complete("NavigationStack", "barForegroundColor"),
        .complete("NavigationStack", "popped"),
        .complete("Page", "appearing"),
        .complete("Page", "background"),
        .complete("Page", "disappearing"),
        .complete("Page", "hasBackButton"),
        .complete("Page", "hasNavigationBar"),
        .complete("Page", "icon"),
        .complete("Page", "navigatedFrom"),
        .complete("Page", "navigatedTo"),
        .complete("Page", "navigatingFrom"),
        .complete("Page", "padding"),
        .complete("Page", "title"),
        .complete("RadioButton", "groupName"),
        .complete("Span", "background"),
        .complete("Span", "fontAttributes"),
        .complete("Span", "fontFamily"),
        .complete("Span", "fontSize"),
        .complete("Span", "text"),
        .complete("Span", "textCase"),
        .complete("Span", "textColor"),
        .complete("Span", "textDecorations"),
        .complete("SplitView", "isSidebarVisible"),
        .complete("SplitView", "isSidebarVisibleChanged"),
        .complete("TabbedView", "currentPage"),
        .complete("TabbedView", "currentPageChanged"),
        .complete("ToolbarItem", "placement"),
        .complete("ToolbarItem", "priority"),
        .complete("Window", "modalPopped"),
    ]

    /// What UIKit's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = UIKitRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames, acts: HostActs.performed.map(\.name))
    }

    /// What UIKit realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(records: records, unrealized: unrealized, viewless: viewless, notPlanned: [:]).and(declaration)
    }
}
#endif
