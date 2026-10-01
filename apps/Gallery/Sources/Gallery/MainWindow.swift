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

    /// What the window's bar says - the Window bar sample writes it. See
    /// Samples/Windows/WindowBarSample.swift.
    let bar: WindowBarState

    // MARK: - The window itself

    /// This window as it runs: what it is called, how big it is, and where it
    /// stands in its life - written in `page` below, the one place the
    /// window is sure to be built.
    @Environment private var window: WindowSession

    /// The gallery this window is in - the scene the ⓘ opens the inspector of.
    @Environment private var scene: SceneSession

    // MARK: - What the user is looking at

    /// THE ARRANGEMENT, and it is three ordinary values: a split view holding two
    /// pages, a stack holding an array, a set of tabs holding a selection.
    var page: any Page {
        // What is over all of it: the pages presented over the split view, the
        // stack and the bars alike - empty almost always: presenting is
        // `sheets.append`, and a sheet the user drags down shortens the array
        // itself.
        ModalStack(nav.$sheets) {
            SplitView(nav.$menuOpen) {
                MenuPage(
                    catalog: catalog,
                    nav: nav,
                    log: log,
                    listsHiddenRow: nav.listsHiddenRow)
            } detail: {
                detail()
            }
            // The gallery's own actions, declared once around every page: a page's
            // own stand nearer the title, and these keep their place at the edge.
            // Icons give both a stable native footprint; their captions remain
            // available to accessibility and to platforms that show text.
            .toolbar(id: "gallery") {
                ToolbarItem.inspector(scene)
                    .text("Inspector")
                    .icon("nav_inspect_dark.png")

                if !nav.showing(.home) {
                    ToolbarItem.home(nav)
                }

                if bar.showsSurprise {
                    ToolbarItem("Surprise me")
                        .icon("nav_surprise_chrome.png")
                        .onClicked { nav.surprise(from: catalog, on: device.formFactor) }
                }
            }
            // What the window's bar says of the gallery: its name and mark, and
            // the line the Window bar sample types - where the platform's
            // chrome names the application.
            .barTitle("StateUI")
            .barSubtitle(bar.subtitle)
            .barIcon("stateui_mark.png")
            // The bars of both panes, in the gallery's accent; their foreground
            // stays white against it in both themes.
            .barBackgroundColor(barColour)
            .barForegroundColor(Palette.onBrand)
            // The window's notice, over every page while the gallery says so.
            .overlays {
                if nav.windowNotice {
                    WindowNotice(words: "Over every page", shown: nav.$windowNotice)
                }
            }
            // A size and a minimum: the size is the window's as it opens, the
            // minimum how small the user may drag it before the layout stops
            // making sense. A phone ignores both, an app there being the whole
            // screen - and there is no `x` or `y` on purpose: pinning an app to
            // the same corner of the screen at every launch is worse than letting
            // the platform place it.
            .onCreated {
                window.title = "StateUI Gallery"
                window.width = 1100
                window.height = 800
                #if APPKIT
                // The AppKit window shows the desktop through it from the start, in
                // the accent's tint.
                window.isTranslucent = true
                #endif
                window.minimumWidth = 700
                window.minimumHeight = 500
                window.maximumWidth = 1600
                window.maximumHeight = 1200
                window.isMaximizable = true
                window.isMinimizable = true

                // On a desktop the menu is a sidebar beside the page.
                if device.formFactor == .desktop {
                    nav.menuOverlays = false
                }

                log.note("created")
            }
        } destination: { _ in
            ModalPage(nav: nav)
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
    @PageBuilder
    func detail() -> any Page {
        if case .tabs = nav.section {
            tabs()
        } else {
            NavigationStack(nav.$path) {
                root()
            } destination: { route in
                page(for: route, path: nav.$path)
            }
        }
    }

    /// The page under everything, for the section the menu chose.
    ///
    /// HOME is the root of the main stack and a group is PUSHED onto it - see
    /// `Navigation.openGroup` - so this answers three sections rather than a
    /// group each. The user's way back out of anything is therefore the
    /// platform's own back button, all the way to the run of group cards the
    /// gallery opens with.
    @PageBuilder
    func root() -> any Page {
        switch nav.section {
        case .home:
            HomePage(catalog: catalog, nav: nav)

        case .hidden:
            HiddenPage(nav: nav)

        case .tabs:
            // Answered by `tabs()` above, which is what that section is for.
            HomePage(catalog: catalog, nav: nav)
        }
    }

    /// The page for one route on a stack, wherever that stack is.
    ///
    /// A `switch` over the author's own type: the compiler proves every route
    /// has a page, where a registered route STRING is checked by nothing but
    /// the user's eyes.
    ///
    /// - Parameter route: which page the stack asked for.
    /// - Parameter path: the stack this page is ON, so a page that pushes or
    ///   pops writes the array it is a member of - the main one, or the tab's.
    @PageBuilder
    func page(for route: Route, path: Binding<[Route]>) -> any Page {
        switch route {
        case .group(let route):
            if let group = catalog.groups.first(where: { $0.route == route }) {
                GroupPage(group: group, nav: nav)
            } else {
                MissingPage(id: route, nav: nav, path: path)
            }

        case .sample(let id):
            if let sample = catalog.sample(id: id) {
                SamplePage.shown(sample, nav: nav, bar: barColour)
            } else {
                MissingPage(id: id, nav: nav, path: path)
            }

        case .level(let level):
            LevelPage(level: level, nav: nav, path: path)

        case .item(let item):
            ItemPage(item: item, nav: nav, path: path)

        case .layer(let depth):
            ToolbarLayerPage(depth: depth, path: path)
        }
    }

    /// The one section that is not a stack: a `TabbedView` over the author's own
    /// enum, with a stack inside the first tab.
    func tabs() -> any Page {
        TabbedView(nav.tabs) { which in
            switch which {
            case .stack:
                NavigationStack(nav.$tabsPath) {
                    TabsPage(nav: nav, path: nav.$tabsPath)
                } destination: { route in
                    page(for: route, path: nav.$tabsPath)
                }
                // A tab's caption and picture are the TAB PAGE's, and the tab
                // page here is the stack rather than what is inside it -
                // measured, and it is where the first live run showed no icons
                // at all.
                .title("Stack")
                .icon(ImageSource(light: "tab_bar.png", dark: "tab_bar_dark.png"))

            case .second:
                SecondTabPage(nav: nav)

            case .extra(let number):
                TabsExtraPage(nav: nav, number: number)
            }
        }
        .selection(nav.$tab)
    }

    // MARK: - The window's own chrome

    /// What the bars are painted in: the gallery's accent, with three fifths
    /// let through while the desktop shows through the window.
    private var barColour: Color {
        window.isTranslucent == true ? style.accent.translucentColor : style.accent.color
    }
}
