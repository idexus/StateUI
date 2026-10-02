// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the Android Views column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum AndroidRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: Set<String> = []

    /// The entries this host leaves to the application, which registers its own control for each: the platform has
    /// no map of its own, and a map needs a provider and its key.
    static let byApplication: Set<String> = ["Map", "Pin"]

    /// What the running host realizes none of: what it never makes, and what it leaves to the application.
    static var unmade: Set<String> {
        unrealized.union(byApplication)
    }

    /// The entries this host presents with no view of their own - a span is a run of its label's text - so
    /// no tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["Span"]

    /// The entries a phone will not have; none yet.
    static let notPlanned: [String: String] = [:]

    /// Every record, the tiers' first.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("BarElement", "barBackgroundColor"),
        .partial("BarElement", "barForegroundColor", missing: "The actions' words take the bar's light or dark theme, as Android's own bars do; the title, the line under it, the navigation button and the pictures take the colour itself - on a tab row, the chosen tab's words."),
        .notPlanned("BarElement", "barIcon",
                    reason: "An Android bar is its stack's own: it shows its page's title, and no application's mark."),
        .complete("BarElement", "barSubtitle"),
        .notPlanned("BarElement", "barTitle",
                    reason: "An Android bar is its stack's own and names its page; an application names itself in none."),
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "isDestructive"),
        .complete("MenuItemElement", "isEnabled"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "icon"),
        .complete("PageElement", "title"),
        .partial("VisualElement", "accessibilityHeadingLevel", missing: "Android marks a heading, not its level: every level is a heading."),
        .partial("View", "panTouchCount", missing: "The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off."),
        .complete("VisualElement", "style"),

        // MARK: Entries - a control's or a part's own
        .partial("Button", "aspect", missing: "Android's button has no covering scale: `.fill` fits the icon, as `.fit` does."),
        .unrealized("ItemsView", "style", why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .complete("Menu", "isEnabled"),
        .complete("Menu", "text"),
        .complete("MenuBar", "order"),
        .complete("ModalStack", "popped"),
        .notPlanned("TextField", "showsClearButton", reason: "Android's text field has no button of its own that empties it."),
        .notPlanned("Page", "backButtonTitle", reason: "Android's way back in the bar is an arrow, with no words."),
        .notPlanned("InputView", "isSpellCheckEnabled",
                    reason: "Android has no switch for spell checking alone: its marks go with the suggestions, which `isTextPredictionEnabled` turns off."),
        .notPlanned("MenuItem", "accessibilityIdentifier",
                    reason: "An Android menu entry holds no identifier: automation finds it by its title."),
        .notPlanned("MenuItem", "icon",
                    reason: "Android's menus - a view's context menu, a bar's overflow and its submenus - draw their entries' words alone."),
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
        .complete("Span", "background"),
        .complete("Span", "fontAttributes"),
        .complete("Span", "fontSize"),
        .complete("Span", "text"),
        .complete("Span", "textCase"),
        .complete("Span", "textColor"),
        .complete("Span", "textDecorations"),
        .complete("SplitView", "isSidebarVisible"),
        .complete("SplitView", "isSidebarVisibleChanged"),
        .complete("TabbedView", "currentPage"),
        .complete("TabbedView", "currentPageChanged"),
        .notPlanned("ToolbarItem", "accessibilityIdentifier",
                    reason: "An Android bar action is a menu entry, which holds no identifier: automation finds it by its title."),
        .complete("ToolbarItem", "icon"),
        .complete("ToolbarItem", "placement"),
        .partial("ToolbarItem", "showsText", missing: "Android shows the words beside the picture only where the bar has room: an upright phone keeps the picture alone."),
        .complete("ToolbarItems", "order"),
        .notPlanned("ToolbarItems", "side",
                    reason: "Android's bar has no leading edge beside its navigation button: a leading group stands first among the actions."),
        .complete("Window", "activated"),
        .complete("Window", "created"),
        .complete("Window", "deactivated"),
        .complete("Window", "destroying"),
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
        HostRegister(
            records: records, unrealized: unrealized, viewless: viewless, notPlanned: notPlanned,
            byApplication: byApplication
        ).and(declaration)
    }
}
