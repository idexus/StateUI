// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry - the library's elements it makes none of, which it shows by name as
/// unsupported - and, member by member, what its records say: the Web column of the control dictionary.
/// Design: docs/design/contracts/dictionary.md#marks
enum WebRealization {
    /// The elements the host makes itself, outside the registry: the pages, the arrangements they stand in, and
    /// what a window lays over them.
    static let madeByHost: Set<NodeType> = [.page, .navigationStack, .splitView, .tabView, .overlay]

    /// The entries this host leaves to the application, which registers its own control for each: the browser has
    /// no map of its own, and a map needs a provider and its key.
    static let byApplication: Set<String> = ["Map", "Marker"]

    /// The entries this host presents with no view of their own: a span is a run of its text's words.
    static let viewless: Set<String> = ["TextSpan"]

    /// What the host's own records say, member by member, before what its registry says: what it realizes through
    /// the host layer's pages and chrome, outside the registry, and what a page never asks of the browser's window.
    static let records: [HostRecord] = [
        // MARK: Tiers - a member every wearer realizes alike
        .complete("BarElement", "barBackgroundColor"),
        .complete("BarElement", "barForegroundColor"),
        .notPlanned("BarElement", "barIcon",
                    reason: "A page's bar names its page and the application, and no mark: the browser's tab shows the site's icon."),
        .complete("BarElement", "barSubtitle"),
        .complete("BarElement", "barTitle"),
        .complete("MenuBar", "order"),
        .complete("Menu", "isEnabled"),
        .complete("Menu", "text"),
        .complete("MenuItemElement", "clicked"),
        .complete("MenuItemElement", "icon"),
        .complete("MenuItemElement", "isDestructive"),
        .complete("MenuItemElement", "isEnabled"),
        .complete("MenuItemElement", "text"),
        .complete("PageElement", "icon"),
        .complete("PageElement", "title"),
        .complete("VisualElement", "style"),
        .partial("VisualElement", "background", missing: "A brush fills the view with its first colour alone; a blur and glass are drawn by a layout, and elsewhere a blur's colour stands in."),
        .unrealized("ItemsView", "style", why: "No style can name an ItemsView: a style names its control by an "
            + "initializer that sets nothing, which a list of some items has not."),

        // MARK: Entries - a control's or a part's own
        .complete("ModalStack", "popped"),
        .complete("NavigationStack", "popped"),
        .complete("Page", "appearing"),
        .complete("Page", "backButtonTitle"),
        .complete("Page", "background"),
        .complete("Page", "disappearing"),
        .complete("Page", "navigatedFrom"),
        .complete("Page", "navigatedTo"),
        .complete("Page", "navigatingFrom"),
        .complete("Page", "showsBackButton"),
        .complete("Page", "showsNavigationBar"),
        .complete("RadioButton", "groupName"),
        .complete("SplitView", "showsSidebar"),
        .complete("SplitView", "showsSidebarChanged"),
        .notPlanned("Slider", "background", reason: "The browser draws its slider over the whole box and paints no "
            + "background under it."),
        .complete("TabView", "selectedTab"),
        .complete("TabView", "selectedTabChanged"),
        .complete("TextSpan", "background"),
        .complete("TextSpan", "fontAttributes"),
        .complete("TextSpan", "fontFamily"),
        .complete("TextSpan", "fontSize"),
        .complete("TextSpan", "text"),
        .complete("TextSpan", "textCase"),
        .complete("TextSpan", "textColor"),
        .complete("TextSpan", "textDecorations"),
        .complete("TextSpan", "tracking"),
        .complete("ToolbarItem", "placement"),
        .complete("ToolbarItem", "showsText"),
        .complete("ToolbarItemGroup", "order"),
        .complete("ToolbarItemGroup", "side"),
        .complete("Scene", "activated"),
        .complete("Scene", "deactivated"),
        .complete("Scene", "stopped"),
        .notPlanned("Scene", "windowClosed", reason: "A page's one window closes with its tab, which hears nothing after."),
        .notPlanned("Window", "windowType", reason: "A page is one window: it opens none of a kind."),
        .notPlanned("Window", "windowValue", reason: "A page is one window: it opens none for a value."),
        .complete("Window", "activated"),
        .complete("Window", "created"),
        .complete("Window", "deactivated"),
        .complete("Window", "destroying"),
        .complete("Window", "resumed"),
        .complete("Window", "stopped"),
        .notPlanned("Window", "floatsOnTop", reason: "A page keeps no browser window above the others: the system stacks them."),
        .notPlanned("Window", "height", reason: "A page sizes no browser window: the user does, and the page fills it."),
        .notPlanned("Window", "hidesWhenInactive",
                    reason: "The browser shows a page whenever its tab shows, whichever application the user is in."),
        .notPlanned("Window", "isMaximizable", reason: "A page asks nothing of how the browser's window is resized."),
        .notPlanned("Window", "isMinimizable", reason: "A page asks nothing of how the browser's window is put away."),
        .partial("Grid", "background", missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its colour."),
        .partial("HStack", "background", missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its colour."),
        .partial("VStack", "background", missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its colour."),
        .partial("ZStack", "background", missing: "A page has no glass: glass is drawn as the blur as clear as it is, a filter under its colour."),
        .partial("Window", "background", missing: "A page draws its window opaque: a blur or glass shows its colour."),
        .notPlanned("Window", "maximumHeight", reason: "A page bounds no browser window: the user sizes it."),
        .notPlanned("Window", "maximumWidth", reason: "A page bounds no browser window: the user sizes it."),
        .notPlanned("Window", "minimumHeight", reason: "A page bounds no browser window: the user sizes it."),
        .notPlanned("Window", "minimumWidth", reason: "A page bounds no browser window: the user sizes it."),
        .complete("Window", "title"),
        .notPlanned("Window", "width", reason: "A page sizes no browser window: the user does, and the page fills it."),
        .notPlanned("Window", "x", reason: "A page places no browser window: the system does."),
        .notPlanned("Window", "y", reason: "A page places no browser window: the system does."),
    ] + pickerOpening + dayFields

    /// A day's and a time's field: left to right, whatever the direction around them.
    private static let dayFields: [HostRecord] = ["DatePicker", "TimePicker"].map { picker in
        .notPlanned(picker, "layoutDirection", reason: "The browser lays a day's and a time's field out left to right "
            + "in every direction, over any the page gives it.")
    }

    /// A picker's list, a day's calendar and a time's clock: the browser's own, opened at the user's press.
    private static let pickerOpening: [HostRecord] = ["DatePicker", "Picker", "TimePicker"].flatMap { picker in
        [
            .notPlanned(picker, "isOpen", reason: "The browser opens a picker's list or calendar only at the user's "
                + "press, and closes it at the user's hand alone."),
            .notPlanned(picker, "opened", reason: "The browser says nothing as a picker's list or calendar opens."),
            .notPlanned(picker, "closed", reason: "The browser says nothing as a picker's list or calendar closes."),
        ] as [HostRecord]
    }

    /// The acts this host performs: every host's (`HostActs.performed`), the files (`HostActs.files`), a list
    /// scrolled to an item, and a web view's steps and scripts.
    static let acts: [any ContractMember] = HostActs.performed + HostActs.files + [
        ItemsViewContract.scrollTo, WebViewContract.goBack, WebViewContract.goForward, WebViewContract.reload,
        WebViewContract.evaluateJavaScript,
    ]

    @MainActor static var unmade: Set<String> {
        Set(LibraryContracts.elements.map { $0.nodeType.name })
            .subtracting(WebRegistrations.registry.realization.elements)
            .subtracting(NodeType.viewlessTypes.map(\.name))
            .subtracting(madeByHost.map(\.name))
    }

    /// What the Web realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        let registry = WebRegistrations.registry
        return HostRegister(
            records: records, unrealized: unmade.subtracting(byApplication), viewless: viewless,
            byApplication: byApplication
        ).and(HostDeclaration(realization: registry.realization, shared: registry.sharedNames, acts: acts.map(\.name)))
    }
}
