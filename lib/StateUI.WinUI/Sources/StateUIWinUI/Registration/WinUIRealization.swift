// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the WinUI 3 column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum WinUIRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: Set<String> = [
        "Map", "Pin", "PositionIndicator",
    ]

    /// The entries this host presents with no view of their own - a span is a run of its label's words - so no
    /// tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["Span"]

    /// The entries Windows will not have; none.
    static let notPlanned: [String: String] = [:]

    /// Every record, the tiers' first.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("BarElement", "barBackgroundColor"),
        .complete("BarElement", "barForegroundColor"),
        .complete("BarElement", "barIcon"),
        .complete("BarElement", "barSubtitle"),
        .complete("BarElement", "barTitle"),
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "icon"),
        .complete("MenuItemElement", "isDestructive"),
        .complete("MenuItemElement", "isEnabled"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "icon"),
        .complete("PageElement", "title"),
        .complete("VisualElement", "style"),

        // MARK: Entries - a control's or a part's own
        .partial("DatePicker", "format", missing: "WinUI writes \"D\" and \"d\" in the user's own way, and any other pattern as \"d\"."),
        .unrealized("ItemsView", "style", why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .complete("Menu", "isEnabled"),
        .complete("Menu", "text"),
        .complete("MenuBar", "order"),
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
        .complete("RadioButton", "groupName"),
        .partial("SearchField", "horizontalTextAlignment", missing: "The placeholder stands at the start: "
            + "AutoSuggestBox's text box template aligns only the words typed."),
        .complete("Scene", "activated"),
        .complete("Scene", "deactivated"),
        .complete("Scene", "destroying"),
        .complete("Scene", "stopped"),
        .complete("Scene", "windowClosed"),
        .complete("Scene", "windowRestored"),
        .complete("Span", "background"),
        .complete("Span", "characterSpacing"),
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
        .partial("TextField", "isPassword", missing: "A PasswordBox has no read-only state, alignment, case, caret "
            + "or selection: a password field keeps none of these."),
        .partial("TimePicker", "format", missing: "WinUI's time picker writes hours and minutes as the user's clock does, whatever the format asks: no seconds, no pattern."),
        .complete("ToolbarItem", "placement"),
        .complete("ToolbarItems", "order"),
        .complete("ToolbarItems", "side"),
        .complete("ToolbarItem", "showsText"),
        .notPlanned("WebView", "panTouchCount", reason: webViewTakesTheHand),
        .notPlanned("WebView", "panUpdated", reason: webViewTakesTheHand),
        .notPlanned("WebView", "panXChannel", reason: webViewTakesTheHand),
        .notPlanned("WebView", "panYChannel", reason: webViewTakesTheHand),
        .notPlanned("WebView", "pinchUpdated", reason: webViewTakesTheHand),
        .notPlanned("WebView", "pointerEntered", reason: webViewTakesTheHand),
        .notPlanned("WebView", "pointerExited", reason: webViewTakesTheHand),
        .notPlanned("WebView", "pointerMoved", reason: webViewTakesTheHand),
        .notPlanned("WebView", "pointerPressed", reason: webViewTakesTheHand),
        .notPlanned("WebView", "pointerReleased", reason: webViewTakesTheHand),
        .notPlanned("WebView", "swipeDirection", reason: webViewTakesTheHand),
        .notPlanned("WebView", "swipeThreshold", reason: webViewTakesTheHand),
        .notPlanned("WebView", "swiped", reason: webViewTakesTheHand),
        .notPlanned("WebView", "tapCount", reason: webViewTakesTheHand),
        .notPlanned("WebView", "tapped", reason: webViewTakesTheHand),
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
        .complete("Window", "resumed"),
        .complete("Window", "stopped"),
        .complete("Window", "title"),
        .complete("Window", "width"),
        .complete("Window", "windowType"),
        .complete("Window", "windowValue"),
        .complete("Window", "x"),
        .complete("Window", "y"),
    ]

    /// Why a web view hears none of the user's hand as a view does.
    static let webViewTakesTheHand = "WebView2 gives the user's hand to its page: listened to by WinUI, it ends the "
        + "process (fail-fast in Microsoft.UI.Xaml.Controls)."

    /// What WinUI's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = WinUIRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames,
            acts: (HostActs.performed + [ApplicationContract.persistSceneValue, ItemsViewContract.scrollTo]
                + WinUIRegistrations.webActs).map(\.name))
    }

    /// What WinUI realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(records: records, unrealized: unrealized, viewless: viewless, notPlanned: notPlanned).and(declaration)
    }
}
