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
    static let unrealized: Set<String> = []

    /// The entries this host presents with no view of their own - a span is a run of its label's words - so no
    /// tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["TextSpan"]

    /// The entries an iPhone and an iPad will not have; none.
    static let notPlanned: [String: String] = [:]

    /// Every record, beside what the registry's export says.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("BarElement", "barBackgroundColor"),
        .complete("BarElement", "barForegroundColor"),
        .notPlanned("BarElement", "barIcon",
                    reason: "A UIKit bar is each page's own: it shows that page's title, and no application's mark."),
        .complete("BarElement", "barSubtitle"),
        .notPlanned("BarElement", "barTitle",
                    reason: "A UIKit bar is each page's own and names that page; an application names itself in none."),
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "icon"),
        .complete("MenuItemElement", "isEnabled"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "icon"),
        .complete("PageElement", "title"),
        .complete("VisualElement", "ignoresInput"),
        .complete("VisualElement", "layoutDirection"),
        .complete("VisualElement", "style"),

        // MARK: Entries - a control's or a part's own
        .unrealized("ItemsView", "style", why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .partial("Menu", "isEnabled", missing: "UIKit holds no menu out of reach itself: each of its entries is."),
        .partial("Layout", "avoidsSafeArea", missing: "UIKit lets a page's own layout under the bars and the notch; "
            + "a layout deeper in stands where its page puts it, and none stands clear of the keyboard."),
        .partial("View", "panTouchCount", missing: "The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off."),
        .complete("Menu", "text"),
        .complete("MenuBar", "order"),
        .complete("ModalStack", "popped"),
        .complete("MenuItem", "isDestructive"),
        .complete("NavigationStack", "popped"),
        .complete("Page", "appearing"),
        .complete("Page", "backButtonTitle"),
        .complete("Page", "background"),
        .complete("Page", "disappearing"),
        .complete("Page", "showsBackButton"),
        .complete("Page", "showsNavigationBar"),
        .complete("Page", "icon"),
        .complete("Page", "navigatedFrom"),
        .complete("Page", "navigatedTo"),
        .complete("Page", "navigatingFrom"),
        .complete("Page", "title"),
        .complete("RadioButton", "groupName"),
        .complete("Scene", "activated"),
        .complete("Scene", "deactivated"),
        .complete("Scene", "stopped"),
        .complete("Scene", "windowClosed"),
        .complete("TextSpan", "background"),
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
        .complete("ToolbarItem", "isDestructive"),
        .complete("ToolbarItem", "placement"),
        .notPlanned("ToolbarItem", "showsText", reason: "A UIKit bar button shows its picture or its words, never both."),
        .complete("ToolbarItemGroup", "order"),
        .complete("ToolbarItemGroup", "side"),
        .complete("Window", "activated"),
        .complete("Window", "created"),
        .complete("Window", "deactivated"),
        .complete("Window", "destroying"),
        .notPlanned("Window", "floatsOnTop", reason: "iPadOS stacks its windows itself: UIKit keeps none above the others."),
        .notPlanned("Window", "height", reason: Self.sizedBySystem),
        .notPlanned("Window", "hidesWhenInactive",
                    reason: "iPadOS shows an application's windows itself: UIKit hides none while another is in front."),
        .notPlanned("Window", "isMaximizable",
                    reason: "Any iPadOS window may fill the screen: UIKit keeps none from it."),
        .notPlanned("Window", "isMinimizable", reason: "Any iPadOS window may be put away: UIKit keeps none from it."),
        .notPlanned("Window", "isTranslucent",
                    reason: "iPadOS draws an application's window opaque: no material shows through one."),
        .complete("Window", "resumed"),
        .complete("Window", "stopped"),
        .complete("Window", "title"),
        .notPlanned("Window", "width", reason: Self.sizedBySystem),
        .notPlanned("Window", "x", reason: Self.placedBySystem),
        .notPlanned("Window", "y", reason: Self.placedBySystem),
    ]

    /// Why a window takes no size: the user's hand gives it, and a scene asks only for orientations.
    private static let sizedBySystem =
        "iPadOS sizes its windows itself - the user drags a corner: a UIKit scene asks for no size."

    /// Why a window takes no place.
    private static let placedBySystem = "iPadOS places its windows itself: a UIKit scene asks for no place."

    /// What UIKit's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = UIKitRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames,
            acts: (HostActs.performed + HostActs.files + UIKitRegistrations.webActs + UIKitRegistrations.itemsActs
                + [MapContract.moveToRegion]).map(\.name))
    }

    /// What UIKit realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(records: records, unrealized: unrealized, viewless: viewless, notPlanned: notPlanned).and(declaration)
    }
}
#endif
