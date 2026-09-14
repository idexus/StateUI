import StateUI

/// A gallery's main window: what it is called, how big it opens, what is
/// presented over it - and THE ARRANGEMENT, which is the reason this is a type
/// of its own.
///
/// A window is where an application says what a screenful IS, so everything
/// about the way the gallery moves lives here: the split view holding the menu and
/// the section, the stack the sections push onto, the tabs that one section is
/// arranged as, and the modal stack over all of it. `GalleryScene` next door is
/// then what it should be - the gallery's state, and the windows built from it.
///
/// **The arrangement is one page with a menu on one side and whatever the
/// section asks for on the other.**
/// Moves are typed state assignments. See Gallery/Navigation.swift for the
/// destination types and transitions.
///
/// A pure function of what it is handed - the catalog, where the gallery is,
/// what it looks like, the log its lifecycle is written into and what its
/// chrome says - which is what lets a test build the whole arrangement without
/// reaching into a running application.
struct MainWindow: Window {
    /// Which kind of device this is, from the standard environment - answered by
    /// the host before the first render, so the first window build already knows
    /// whether to wear a title bar.
    @Environment private var device: DeviceInfo

    /// Every sample there is, already built.
    let catalog: Catalog

    /// Where the gallery is: the section, the path, the menu, the sheets and
    /// the tabs.
    let nav: Navigation

    /// What the gallery looks like - its bars are painted in its accent, which
    /// the Colours window chooses.
    let style: SessionStyle

    /// The gallery's log of this window's lifecycle - the state is
    /// `GalleryScene`'s, the moments are this window's.
    let log: WindowLog

    /// What the window's chrome says - the TitleBar sample writes it. See
    /// Samples/Windows/TitleBarSample.swift.
    let bar: TitleBarState

    // MARK: - The window itself

    /// This window as it runs: what it is called, how big it is, and where it
    /// stands in its life - written in `page` below, the one place the
    /// window is sure to be built.
    @Environment private var window: WindowSession

    // MARK: - What the reader is looking at

    /// THE ARRANGEMENT, and it is three ordinary values: a split view holding two
    /// pages, a stack holding an array, a set of tabs holding a selection.
    var page: any Page {
        SplitView(nav.$menuOpen) {
            MenuPage(
                catalog: catalog,
                nav: nav,
                log: log,
                listsHiddenRow: nav.listsHiddenRow)
        } detail: {
            detail()
        }
        // A size and a minimum: the size is the window's as it opens, the
        // minimum how small the reader may drag it before the layout stops
        // making sense. A phone ignores both, an app there being the whole
        // screen - and there is no `x` or `y` on purpose: pinning an app to
        // the same corner of the screen at every launch is worse than letting
        // the platform place it.
        .onCreated {
            window.title = "StateUI Gallery"
            window.width = 1100
            window.height = 800
            window.minimumWidth = 700
            window.minimumHeight = 500
            window.maximumWidth = 1600
            window.maximumHeight = 1200
            window.isMaximizable = true
            window.isMinimizable = true

            // Authored window chrome is meaningful on a desktop host, and
            // there the menu is a sidebar beside the page.
            if device.idiom == .desktop {
                window.titleBar = chrome
                nav.menuOverlays = false
            }

            // What is over all of it: a second arranged list on the window,
            // holding the pages presented over the split view, the stack and the
            // bars alike. Written once - it reads the array as the window
            // builds - and empty almost always: presenting is
            // `sheets.append`, and a sheet the reader drags down truncates
            // the array itself.
            window.modalStack = ModalStack(nav.$sheets) { _ in
                ModalPage(nav: nav)
            }

            log.note("created")
        }
        // The chrome is painted in the gallery's accent, which the Colours
        // window chooses - so the bar is written again when it moves.
        .onChanged(style.accent.color) {
            if device.idiom == .desktop {
                window.titleBar = chrome
            }
        }
        .onChanged(bar.subtitle) {
            if device.idiom == .desktop {
                window.titleBar = chrome
            }
        }
    }

    /// The other half of the split view: the section, arranged the way that section
    /// wants to be.
    ///
    /// Almost always a STACK - a `NavigationStack` over the path, with the
    /// section's own page underneath. The tabs demonstration is the exception,
    /// and it is the reason this is a function rather than one expression: a
    /// `TabbedView` is a page like any other, so a section may simply be one -
    /// and a stack may sit inside a tab, because pages nest without a rule
    /// about which may hold which.
    func detail() -> any Page {
        if case .tabs = nav.section {
            return tabs()
        }

        return NavigationStack(nav.$path) {
            root()
        } destination: { route in
            page(for: route, path: nav.$path)
        }
        // The bar belongs to the navigation arrangement, not one page on it.
        // Its foreground stays white against the gallery accent in both themes.
        .barBackgroundColor(style.accent.color)
        .barTextColor(Palette.onBrand)
    }

    /// The page under everything, for the section the menu chose.
    ///
    /// HOME is the root of the main stack and a group is PUSHED onto it - see
    /// `Navigation.openGroup` - so this answers three sections rather than a
    /// group each. The reader's way back out of anything is therefore the
    /// platform's own back button, all the way to the run of group cards the
    /// gallery opens with.
    func root() -> any View {
        switch nav.section {
        case .home:
            return HomePage(catalog: catalog, nav: nav)

        case .hidden:
            return HiddenPage(nav: nav)

        case .tabs:
            // Answered by `tabs()` above, which is what that section is for.
            return HomePage(catalog: catalog, nav: nav)
        }
    }

    /// The page for one route on a stack, wherever that stack is.
    ///
    /// A `switch` over the author's own type: the compiler proves every route
    /// has a page, where a registered route STRING is checked by nothing but
    /// the reader's eyes.
    ///
    /// - Parameter route: which page the stack asked for.
    /// - Parameter path: the stack this page is ON, so a page that pushes or
    ///   pops writes the array it is a member of - the main one, or the tab's.
    func page(for route: Route, path: Binding<[Route]>) -> any Page {
        switch route {
        case .group(let route):
            guard let group = catalog.groups.first(where: { $0.route == route }) else {
                return MissingPage(id: route, nav: nav, path: path)
            }

            return GroupPage(group: group, nav: nav)

        case .sample(let id):
            guard let sample = catalog.sample(id: id) else {
                return MissingPage(id: id, nav: nav, path: path)
            }

            return SamplePage.shown(sample, nav: nav)

        case .level(let level):
            return LevelPage(level: level, nav: nav, path: path)

        case .item(let item):
            return ItemPage(item: item, nav: nav, path: path)
        }
    }

    /// The one section that is not a stack: a `TabbedView` over the author's own
    /// enum, with a stack inside the first tab.
    ///
    /// Its own flat bar background. The native selector owns the distinction
    /// between selected and unselected tabs.
    func tabs() -> any Page {
        TabbedView(nav.tabs) { which in
            switch which {
            case .stack:
                return NavigationStack(nav.$tabsPath) {
                    TabsPage(nav: nav, path: nav.$tabsPath)
                } destination: { route in
                    page(for: route, path: nav.$tabsPath)
                }
                // A tab's caption and picture are the TAB PAGE's, and the tab
                // page here is the stack rather than what is inside it -
                // measured, and it is where the first live run showed no icons
                // at all.
                .title("Stack")
                .iconImageSource(ImageSource(light: "tab_bar.png", dark: "tab_bar_dark.png"))
                .barBackgroundColor(style.accent.color)
                .barTextColor(Palette.onBrand)

            case .second:
                return SecondTabPage(nav: nav)

            case .extra(let number):
                return TabsExtraPage(nav: nav, number: number)
            }
        }
        .selection(nav.$tab)
        .barBackgroundColor(style.accent.color)
    }

    // MARK: - The window's own chrome

    /// Native desktop chrome whose values and slot contents are described by
    /// the gallery scene. See Samples/Windows/TitleBarSample.swift.
    private var chrome: TitleBar {
        TitleBar("StateUI")
            .subtitle(bar.subtitle)
            .icon("stateui_mark.png")
            .backgroundColor(style.accent.color)
            .foregroundColor(Palette.onBrand)
            .trailingContent {
                ChromeEnd(bar: bar, nav: nav, catalog: catalog)
            }
    }
}

/// The optional action at the trailing edge of the native title area.
private struct ChromeEnd: ContentView {
    /// What the chrome says - the TitleBar sample writes it.
    let bar: TitleBarState

    /// Where the gallery is - what "Surprise me" moves.
    let nav: Navigation

    /// Everything the gallery shows - what "Surprise me" picks from.
    let catalog: Catalog

    /// Which kind of device this is, so the pick leaves out what it cannot show.
    @Environment private var device: DeviceInfo

    var content: any View {
        HStack {
            if bar.showsSurprise {
                Button("Surprise me")
                    .imageSource("nav_surprise_chrome.png")
                    .contentLayout(.left, spacing: 5)
                    .style("ChromeChip")
                    .verticalOptions(.center)
                    .onClicked { nav.surprise(from: catalog, on: device.idiom) }
            }
        }
        .margin(0, 0, 5, 0)
    }
}
