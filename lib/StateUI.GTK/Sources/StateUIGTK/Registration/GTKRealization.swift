// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the GTK 4 column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum GTKRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: Set<String> = [
        "Map", "Pin", "WebView",
    ]

    /// The entries this host presents with no view of their own - a span is a run of its label's words - so no
    /// tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["Span"]

    /// The entries GTK will not have; none.
    static let notPlanned: [String: String] = [:]

    /// Every record, the tiers' first.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("BarElement", "barBackgroundColor"),
        .complete("BarElement", "barForegroundColor"),
        .complete("BarElement", "barSubtitle"),
        .notPlanned("BarElement", "barIcon",
                    reason: "A GNOME header bar is its page's own and shows no application's mark."),
        .notPlanned("BarElement", "barTitle",
                    reason: "A GNOME header bar is its page's own and names that page; an application names itself in none."),
        .complete("MenuBar", "order"),
        .complete("Menu", "isEnabled"),
        .complete("Menu", "text"),
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "icon"),
        .complete("MenuItemElement", "isEnabled"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "title"),
        .complete("VisualElement", "style"),

        // MARK: Entries - a control's or a part's own
        .partial("DatePicker", "format", missing: "GTK writes \"D\" and \"d\" in the user's own way, and any other pattern as \"d\"."),
        .partial("DatePicker", "maximumDate",
                 missing: "GtkCalendar offers every day: one the user picks past the range stands at its end."),
        .partial("DatePicker", "minimumDate",
                 missing: "GtkCalendar offers every day: one the user picks past the range stands at its end."),
        .unrealized("ItemsView", "style", why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .partial("Label", "background", missing: "A brush fills the box with its first colour alone."),
        .notPlanned("MenuItem", "icon", reason: "GNOME's menus show words alone, no picture beside them."),
        .notPlanned("MenuItem", "isDestructive", reason: "GNOME's menus mark no entry as destroying something."),
        .complete("ModalStack", "popped"),
        .complete("NavigationStack", "popped"),
        .complete("Page", "appearing"),
        .complete("Page", "background"),
        .complete("Page", "disappearing"),
        .complete("Page", "hasNavigationBar"),
        .complete("Page", "navigatedFrom"),
        .complete("Page", "navigatedTo"),
        .complete("Page", "navigatingFrom"),
        .complete("Page", "padding"),
        .notPlanned("Picker", "closed", reason: "GTK's drop-down tells no one its list opened or closed."),
        .notPlanned("Picker", "isOpen", reason: "GTK's drop-down tells no one its list opened or closed."),
        .notPlanned("Picker", "opened", reason: "GTK's drop-down tells no one its list opened or closed."),
        .notPlanned("Picker", "tint", reason: "A GNOME drop-down wears no accent: a check in its words' colour marks the choice."),
        .notPlanned("Picker", "title", reason: "GTK's drop-down shows a choice or nothing: it has no words standing for none."),
        .complete("RadioButton", "groupName"),
        .complete("Scene", "activated"),
        .complete("Scene", "deactivated"),
        .complete("Scene", "destroying"),
        .complete("Scene", "stopped"),
        .complete("Scene", "windowClosed"),
        .complete("Scene", "windowRestored"),
        .complete("Span", "background"),
        .complete("Span", "fontAttributes"),
        .complete("Span", "fontSize"),
        .complete("Span", "text"),
        .complete("Span", "textColor"),
        .complete("Span", "textDecorations"),
        .complete("SplitView", "isSidebarVisible"),
        .complete("SplitView", "isSidebarVisibleChanged"),
        .complete("TabbedView", "currentPage"),
        .complete("TabbedView", "currentPageChanged"),
        .partial("TimePicker", "format",
                 missing: "GTK writes hours and minutes in the user's own clock, whatever the format asks: no seconds, no pattern."),
        .complete("ToolbarItem", "placement"),
        .complete("ToolbarItem", "showsText"),
        .complete("ToolbarItems", "order"),
        .complete("ToolbarItems", "side"),
        .complete("Window", "activated"),
        .complete("Window", "created"),
        .complete("Window", "deactivated"),
        .complete("Window", "destroying"),
        .notPlanned("Window", "floatsOnTop", reason: "GTK 4 keeps no window above the others: the desktop stacks them."),
        .complete("Window", "height"),
        .complete("Window", "hidesWhenInactive"),
        .notPlanned("Window", "maximumHeight", reason: "GTK 4 bounds no window from above."),
        .notPlanned("Window", "maximumWidth", reason: "GTK 4 bounds no window from above."),
        .complete("Window", "minimumHeight"),
        .complete("Window", "minimumWidth"),
        .partial("Window", "resumed", missing: "A Wayland desktop tells no window it was minimized, nor brought back."),
        .partial("Window", "stopped", missing: "A Wayland desktop tells no window it was minimized, nor brought back."),
        .complete("Window", "title"),
        .complete("Window", "width"),
        .complete("Window", "windowType"),
        .complete("Window", "windowValue"),
        .notPlanned("Window", "x", reason: "GNOME places its windows itself: GTK 4 asks no place of the desktop."),
        .notPlanned("Window", "y", reason: "GNOME places its windows itself: GTK 4 asks no place of the desktop."),
    ]

    /// What GTK's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = GTKRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames, acts: GTKRegistrations.acts.map(\.name))
    }

    /// What GTK realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(records: records, unrealized: unrealized, viewless: viewless, notPlanned: notPlanned).and(declaration)
    }
}
