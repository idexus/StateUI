// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the Android Views column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum AndroidRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: Set<String> = [
        "Content", "LeadingContent", "Map", "MenuBar", "Pin", "PositionIndicator",
        "TitleBar", "TrailingContent",
    ]

    /// The entries this host presents with no view of their own - a span is a run of its label's text - so
    /// no tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["Span"]

    /// The entries a phone will not have; none yet.
    static let notPlanned: [String: String] = [:]

    /// Every record, the tiers' first.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "isDestructive"),
        .complete("MenuItemElement", "isEnabled"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "icon"),
        .complete("PageElement", "title"),
        .partial("VisualElement", "accessibilityHeadingLevel", missing: "Android marks a heading, not its level: every level is a heading."),
        .complete("VisualElement", "style"),

        // MARK: Entries - a control's or a part's own
        .partial("Button", "aspect", missing: "Android's button has no covering scale: `.fill` fits the icon, as `.fit` does."),
        .complete("Menu", "isEnabled"),
        .complete("Menu", "text"),
        .complete("NavigationStack", "barBackgroundColor"),
        .complete("NavigationStack", "barForegroundColor"),
        .complete("NavigationStack", "popped"),
        .complete("Page", "appearing"),
        .complete("Page", "background"),
        .complete("Page", "disappearing"),
        .complete("Page", "hasBackButton"),
        .complete("Page", "hasNavigationBar"),
        .complete("Page", "navigatedFrom"),
        .complete("Page", "navigatedTo"),
        .complete("Page", "navigatingFrom"),
        .complete("Page", "padding"),
        .partial("Picker", "isOpen", missing: "Android closes the list only when the user does: `false` does not close it."),
        .complete("RadioButton", "groupName"),
        .complete("Scene", "activated"),
        .complete("Scene", "deactivated"),
        .complete("Scene", "destroying"),
        .complete("Scene", "stopped"),
        .complete("Span", "fontSize"),
        .complete("Span", "text"),
        .complete("SplitView", "isSidebarVisible"),
        .complete("SplitView", "isSidebarVisibleChanged"),
        .complete("TabbedView", "currentPage"),
        .complete("TabbedView", "currentPageChanged"),
        .complete("ToolbarItem", "icon"),
        .complete("ToolbarItem", "placement"),
        .complete("ToolbarItem", "priority"),
        .complete("Window", "activated"),
        .complete("Window", "created"),
        .complete("Window", "deactivated"),
        .complete("Window", "destroying"),
        .complete("Window", "modalPopped"),
        .complete("Window", "resumed"),
        .complete("Window", "stopped"),
        .complete("Window", "title"),
    ]

    /// What Android's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = AndroidRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames,
            acts: AndroidRegistrations.acts.map(\.name))
    }

    /// What Android realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(records: records, unrealized: unrealized, viewless: viewless, notPlanned: notPlanned).and(declaration)
    }
}
