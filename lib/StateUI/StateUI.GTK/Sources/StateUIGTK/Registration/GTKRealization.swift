// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the GTK 4 column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum GTKRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: Set<String> = []

    /// The entries this host leaves to the application, which registers its own control for each: the platform has
    /// no map of its own, and a map needs a provider and its key.
    static let byApplication: Set<String> = ["Map", "Marker"]

    /// The entries a backend realizes on this host - a package of its own, for a library GTK does not ship - which
    /// the application's head registers: WebKitGTK's web view. Realized none of until it is registered.
    static let backends: Set<String> = ["WebView"]

    /// What the running host realizes none of: what it never makes, what it leaves to the application, and each
    /// backend no one registered.
    @MainActor static var unmade: Set<String> {
        unrealized.union(byApplication).union(backends.subtracting(GTKRegistrations.registry.realization.elements))
    }

    /// The entries this host presents with no view of their own - a span is a run of its label's words - so no
    /// tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["TextSpan"]

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
        .notPlanned("PageElement", "icon",
                    reason: "GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions."),
        .complete("PageElement", "title"),
        .notPlanned("PropertyContainer", "accessibilityIdentifier", reason: "GTK 4 gives an accessible the identifier "
            + "a GtkBuilder file names alone: none is set on a widget made in code."),
        .partial("VisualElement", "accessibilityHeading", missing: "GTK fixes a widget's role once it is shown: a view "
            + "becomes a heading, or stops being one, only as it is made; its level changes."),
        .partial("VisualElement", "background", missing: "A brush fills the view with its first colour alone."),
        .complete("VisualElement", "layoutDirection"),
        .complete("VisualElement", "style"),

        // MARK: Entries - a control's or a part's own
        .notPlanned("Page", "backButtonTitle", reason: "GNOME's way back in the bar is an arrow, with no words."),
        .notPlanned("SearchField", "submitLabel", reason: "GTK gives an entry no word for the return key of a keyboard on the screen."),
        .notPlanned("TextField", "showsClearButton", reason: "GTK's entry has no button of its own that empties it."),
        .notPlanned("TextField", "submitLabel", reason: "GTK gives an entry no word for the return key of a keyboard on the screen."),
        .complete("Grid", "background"),
        .complete("HStack", "background"),
        .complete("ScrollView", "background"),
        .notPlanned("Switch", "background", reason: "GTK's switch paints its own box as its track: a colour there would "
            + "recolour the track, not lie under it."),
        .complete("VStack", "background"),
        .complete("ZStack", "background"),
        .partial("DatePicker", "format", missing: "GTK writes \"D\" and \"d\" in the user's own way, and any other pattern as \"d\"."),
        .partial("DatePicker", "maximumDate",
                 missing: "GtkCalendar offers every day: one the user picks past the range stands at its end."),
        .partial("DatePicker", "minimumDate",
                 missing: "GtkCalendar offers every day: one the user picks past the range stands at its end."),
        .unrealized("ItemsView", "style", why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .notPlanned("MenuItem", "icon", reason: "GNOME's menus show words alone, no picture beside them."),
        .notPlanned("MenuItem", "isDestructive", reason: "GNOME's menus mark no entry as destroying something."),
        .complete("ModalStack", "popped"),
        .complete("NavigationStack", "popped"),
        .complete("Page", "appearing"),
        .complete("Page", "background"),
        .complete("Page", "disappearing"),
        .complete("Page", "showsBackButton"),
        .complete("Page", "showsNavigationBar"),
        .complete("Page", "navigatedFrom"),
        .complete("Page", "navigatedTo"),
        .complete("Page", "navigatingFrom"),
        .notPlanned("Picker", "closed", reason: "GTK's drop-down tells no one its list opened or closed."),
        .notPlanned("Picker", "horizontalTextAlignment", reason: "GTK's drop-down draws its choice with the factory "
            + "that draws its list: the choice alone takes no alignment without redrawing GNOME's list."),
        .notPlanned("Picker", "isOpen", reason: "GTK's drop-down tells no one its list opened or closed."),
        .notPlanned("Picker", "opened", reason: "GTK's drop-down tells no one its list opened or closed."),
        .notPlanned("Picker", "tint", reason: "A GNOME drop-down wears no accent: a check in its words' colour marks the choice."),
        .notPlanned("Picker", "placeholder", reason: "GTK's drop-down shows a choice or nothing: it has no words standing for none."),
        .complete("RadioButton", "groupName"),
        .complete("Scene", "activated"),
        .complete("Scene", "deactivated"),
        .complete("Scene", "stopped"),
        .complete("Scene", "windowClosed"),
        .notPlanned("Slider", "released", reason: "GTK's scale tells no one it is held: its range claims the "
            + "press, and GTK denies every other gesture on it."),
        .notPlanned("Slider", "pressed", reason: "GTK's scale tells no one it is held: its range claims the "
            + "press, and GTK denies every other gesture on it."),
        .complete("TextSpan", "background"),
        .complete("TextSpan", "tracking"),
        .complete("TextSpan", "fontAttributes"),
        .complete("TextSpan", "fontFamily"),
        .complete("TextSpan", "fontSize"),
        .complete("TextSpan", "text"),
        .complete("TextSpan", "textCase"),
        .complete("TextSpan", "textColor"),
        .complete("TextSpan", "textDecorations"),
        .complete("SplitView", "showsSidebar"),
        .complete("SplitView", "showsSidebarChanged"),
        .complete("TabView", "selectedTab"),
        .complete("TabView", "selectedTabChanged"),
        .partial("TextEditor", "layoutDirection",
                 missing: "Its placeholder stands at the left edge whichever way the words are written."),
        .partial("TimePicker", "format",
                 missing: "GTK writes hours and minutes in the user's own clock, whatever the format asks: no seconds, no pattern."),
        .complete("ToolbarItem", "isDestructive"),
        .complete("ToolbarItem", "placement"),
        .complete("ToolbarItem", "showsText"),
        .complete("ToolbarItemGroup", "order"),
        .complete("ToolbarItemGroup", "side"),
        .complete("Window", "activated"),
        .complete("Window", "background"),
        .complete("Window", "created"),
        .complete("Window", "deactivated"),
        .complete("Window", "destroying"),
        .notPlanned("Window", "floatsOnTop", reason: "GTK 4 keeps no window above the others: the desktop stacks them."),
        .complete("Window", "height"),
        .complete("Window", "hidesWhenInactive"),
        .notPlanned("Window", "isMaximizable",
                    reason: "The desktop fills the screen with any GTK 4 window it can resize: none forbids that alone."),
        .notPlanned("Window", "isMinimizable", reason: "GTK 4 asks the desktop to keep no window from being put away."),
        .notPlanned("Window", "isTranslucent", reason: "GNOME draws its windows opaque: no material shows through one."),
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
        HostRegister(
            records: records,
            unrealized: unrealized.union(backends.subtracting(GTKRegistrations.registry.realization.elements)),
            viewless: viewless, notPlanned: notPlanned, byApplication: byApplication
        ).and(declaration)
    }
}
