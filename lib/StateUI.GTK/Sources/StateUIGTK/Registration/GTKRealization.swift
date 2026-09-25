// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What this host realizes beyond its registry, whose export says the rest - the GTK 4 column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum GTKRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: Set<String> = [
        "Canvas", "Content", "ContextMenu", "DatePicker", "LeadingContent", "Map", "Menu", "MenuBar", "MenuItem",
        "MenuSeparator", "ModalStack", "Pin", "PositionIndicator", "TimePicker", "TrailingContent", "WebView",
    ]

    /// The entries this host presents with no view of their own - a span is a run of its label's words - so no
    /// tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["Span"]

    /// The entries GTK will not have; none.
    static let notPlanned: Set<String> = []

    /// Every record, the tiers' first.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "icon"),
        .complete("MenuItemElement", "isEnabled"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "title"),

        // MARK: Entries - a control's or a part's own
        .complete("Page", "appearing"),
        .complete("Page", "disappearing"),
        .complete("Page", "hasNavigationBar"),
        .complete("Page", "navigatedFrom"),
        .complete("Page", "navigatedTo"),
        .complete("Page", "navigatingFrom"),
        .complete("RadioButton", "groupName"),
        .complete("Span", "background"),
        .complete("Span", "fontAttributes"),
        .complete("Span", "fontSize"),
        .complete("Span", "text"),
        .complete("Span", "textColor"),
        .complete("Span", "textDecorations"),
        .complete("SplitView", "isSidebarVisible"),
        .complete("TabbedView", "currentPage"),
        .complete("TitleBar", "background"),
        .complete("TitleBar", "barForegroundColor"),
        .complete("ToolbarItem", "placement"),
        .complete("ToolbarItem", "priority"),
    ]

    /// What GTK's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = GTKRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames, acts: GTKRegistrations.acts.map(\.name))
    }

    /// What GTK realizes, member by member: these records before what its registry says.
    @MainActor static var marks: HostMarks {
        HostMarks(records: records, unrealized: unrealized, viewless: viewless, notPlanned: notPlanned).and(declaration)
    }
}
