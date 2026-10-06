// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the WinUI 3 column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
enum WinUIRealization {
    /// The entries this host realizes none of: those it shows as unsupported, and the parts of one.
    static let unrealized: Set<String> = []

    /// The entries this host leaves to the application, which registers its own control for each: the platform has
    /// no map of its own, and a map needs a provider and its key.
    static let byApplication: Set<String> = ["Map", "Marker"]

    /// The entries a backend realizes on this host - a package of its own, for a library WinUI does not ship - which
    /// the application's head registers: WebView2's web view. Realized none of until it is registered.
    static let backends: Set<String> = ["WebView"]

    /// What the running host realizes none of: what it never makes, what it leaves to the application, and each
    /// backend no one registered.
    @MainActor static var unmade: Set<String> {
        unrealized.union(byApplication).union(backends.subtracting(WinUIRegistrations.registry.realization.elements))
    }

    /// The entries this host presents with no view of their own - a span is a run of its label's words - so no
    /// tier's record reaches them: only a member the entry's own records name is realized.
    static let viewless: Set<String> = ["TextSpan"]

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
        .complete("VisualElement", "ignoresInput"),
        .complete("VisualElement", "layoutDirection"),
        .complete("VisualElement", "style"),

        // MARK: Entries - a control's or a part's own
        .notPlanned("ActivityIndicator", "background", reason: "WinUI's progress ring paints its Background as its "
            + "track, no ground under its frame."),
        .partial("Canvas", "background", missing: "A brush fills the canvas with its first colour alone."),
        .notPlanned("ColorBox", "background", reason: figurePaintsNoGround),
        .notPlanned("Ellipse", "background", reason: figurePaintsNoGround),
        .notPlanned("Image", "background", reason: "WinUI's picture paints the picture alone, no ground around it."),
        .notPlanned("Line", "background", reason: figurePaintsNoGround),
        .notPlanned("Path", "background", reason: figurePaintsNoGround),
        .notPlanned("Polygon", "background", reason: figurePaintsNoGround),
        .notPlanned("Polyline", "background", reason: figurePaintsNoGround),
        .notPlanned("ProgressBar", "background", reason: "WinUI's progress bar paints its Background as its track, no "
            + "ground under its frame."),
        .notPlanned("Rectangle", "background", reason: figurePaintsNoGround),
        .unrealized("WebView", "background", why: "WebView2 is no control and takes no Background: what shows "
            + "where its page paints nothing is its DefaultBackgroundColor, which the backend does not set yet."),
        .unrealized("ActivityIndicator", "ignoresInput", why: hitOnlyWherePainted),
        .unrealized("ColorBox", "ignoresInput", why: hitOnlyWherePainted),
        .partial("DatePicker", "format", missing: "WinUI writes \"D\" and \"d\" in the user's own way, and any other pattern as \"d\"."),
        .unrealized("Ellipse", "ignoresInput", why: hitOnlyWherePainted),
        .unrealized("Image", "ignoresInput", why: hitOnlyWherePainted),
        .unrealized("ItemsView", "style", why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),
        .unrealized("Line", "ignoresInput", why: hitOnlyWherePainted),
        .complete("Menu", "isEnabled"),
        .complete("Menu", "text"),
        .complete("MenuBar", "order"),
        .complete("ModalStack", "popped"),
        .complete("NavigationStack", "popped"),
        .complete("Page", "appearing"),
        .complete("Page", "background"),
        .complete("Page", "disappearing"),
        .complete("Page", "showsNavigationBar"),
        .complete("Page", "navigatedFrom"),
        .complete("Page", "navigatedTo"),
        .complete("Page", "navigatingFrom"),
        .unrealized("Path", "ignoresInput", why: hitOnlyWherePainted),
        .unrealized("Polygon", "ignoresInput", why: hitOnlyWherePainted),
        .unrealized("Polyline", "ignoresInput", why: hitOnlyWherePainted),
        .complete("RadioButton", "groupName"),
        .unrealized("Rectangle", "ignoresInput", why: hitOnlyWherePainted),
        .partial("SearchField", "horizontalTextAlignment", missing: "The placeholder stands at the start: "
            + "AutoSuggestBox's text box template aligns only the words typed."),
        .complete("Scene", "activated"),
        .complete("Scene", "deactivated"),
        .complete("Scene", "stopped"),
        .complete("Scene", "windowClosed"),
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
        .partial("TextField", "isPassword", missing: "A PasswordBox has no read-only state, alignment, case, caret "
            + "or selection: a password field keeps none of these."),
        .partial("TimePicker", "format", missing: "WinUI's time picker writes hours and minutes as the user's clock does, whatever the format asks: no seconds, no pattern."),
        .complete("ToolbarItem", "placement"),
        .complete("ToolbarItemGroup", "order"),
        .complete("ToolbarItemGroup", "side"),
        .complete("ToolbarItem", "showsText"),
        .notPlanned("WebView", "isEnabled", reason: "WinUI's WebView2 is no control: it keeps no enabled state, and "
            + "its page takes the user's hand whatever the tree says."),
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

    /// Why a figure takes no background on WinUI.
    static let figurePaintsNoGround = "A WinUI shape is its figure alone: it paints no ground around it."

    /// Why a drawing's press is not let through as the tree says.
    static let hitOnlyWherePainted = "WinUI hands a figure, a picture, a colour box and the activity ring only the "
        + "presses on what they paint: an empty one is never pressed, so there is nothing to let through."

    /// Why a web view hears none of the user's hand as a view does.
    static let webViewTakesTheHand = "WebView2 gives the user's hand to its page: listened to by WinUI, it ends the "
        + "process (fail-fast in Microsoft.UI.Xaml.Controls)."

    /// What WinUI's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = WinUIRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames,
            acts: (HostActs.performed + HostActs.files + [ItemsViewContract.scrollTo]).map(\.name))
    }

    /// What WinUI realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(
            records: records,
            unrealized: unrealized.union(backends.subtracting(WinUIRegistrations.registry.realization.elements)),
            viewless: viewless, notPlanned: notPlanned, byApplication: byApplication
        ).and(declaration)
    }
}
