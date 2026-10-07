import StateUI

/// What a gallery window shows: what the window is called, how big it
/// opens, what is presented over it - and THE ARRANGEMENT, which is the reason
/// this is a view of its own.
///
/// The view a window shows is where an application says what a screenful IS, so everything
/// about the way the gallery moves lives here: the split view holding the menu and
/// the section, the stack the sections push onto, the tabs that one section is
/// arranged as, and the modal stack over all of it. `GalleryWindow` next door is
/// then what it should be - the window's state, and the page built from it.
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
struct MainPage: View {
    /// Which kind of device this is, from the standard environment - answered by
    /// the host before the first render, so the first window build already knows
    /// whether the menu stands beside the page.
    @Environment(\.device) private var device

    /// Every sample there is, already built.
    let catalog: Catalog

    /// Where the gallery is: the section, the path, the menu, the sheets and
    /// the tabs.
    let nav: Navigation

    /// What the gallery looks like - its bars are the platform's own, or
    /// painted in the accent the Colours window chooses.
    let style: SessionStyle

    /// The log of this window's lifecycle - kept by `GalleryWindow`.
    let log: WindowLog

    /// What the window's bar says - the Window bar sample writes it. See
    /// Samples/Windows/WindowBarSample.swift.
    let bar: WindowBarState

    // MARK: - The window itself

    /// This window as it runs: what it is called, how big it is, and where it
    /// stands in its life - written in `body` below, the one place the
    /// window is sure to be built.
    @Environment(\.window) private var window

    // MARK: - What the user is looking at

    /// THE ARRANGEMENT, and it is three ordinary values: a split view holding two
    /// pages, a stack holding an array, a set of tabs holding a selection.
    var body: some View {
        // listing: MainPage.modal
        // What is over all of it: the pages presented over the split view, the
        // stack and the bars alike - empty almost always: presenting is
        // `sheets.append`, and a sheet the user dismisses shortens the array
        // itself.
        ModalStack(nav.$sheets) {
        // listing: end
            // listing: MainPage.modal
            // The split view, its bars and its pages - what the sheets are
            // presented over.
            // listing: end
            // listing: MainPage.split
            SplitView(nav.$menuOpen) {
                MenuPage(
                    catalog: catalog,
                    nav: nav,
                    log: log,
                    listsHiddenRow: nav.listsHiddenRow)
            } detail: {
                detail()
            }
            // listing: end
            // listing: MainPage.bar
            // The gallery's own actions, declared once around every page: a page's
            // own stand nearer the title, and these keep their place at the edge.
            // Each wears an icon, which keeps its size on the bar steady; its
            // caption stays for accessibility and for bars that show words.
            .toolbar(id: "gallery") {
                ToolbarItem.inspector(window)
                    .text("Inspector")
                    .icon(ImageSource(light: "nav_inspect.png", dark: "nav_inspect_dark.png"))

                if !nav.showing(.home) {
                    ToolbarItem.home(nav)
                }

                if bar.showsSurprise {
                    ToolbarItem("Surprise me")
                        .icon(ImageSource(light: "nav_surprise.png", dark: "nav_surprise_dark.png"))
                        .onClicked { nav.surprise(from: catalog, on: device.info.formFactor) }
                }
            }
            // What the window's bar says of the gallery: its name and mark,
            // where the platform's chrome names the application, and under the
            // title the line the Window bar sample types.
            .barTitle("StateUI")
            .barSubtitle(bar.subtitle)
            .barIcon("stateui_mark.png")
            // listing: end
            // The bars of both panes, as the gallery's look says.
            .bars(style.bars, in: style.barColour)
            // listing: MainPage.overlays
            // The window's notice, over every page while the gallery says so.
            .overlays {
                if nav.windowNotice {
                    WindowNotice(words: "Over every page", shown: nav.$windowNotice)
                }
            }
            // listing: end
            // listing: MainPage.created
            // The window's name and its size: `width` and `height` are its size
            // as it opens, the minimum how small the user may drag it before the
            // layout stops making sense, the maximum how large. On a phone or a
            // tablet the system sizes the window and these go unused - and the
            // gallery writes no `x` or `y` on purpose: pinning an app to the same
            // corner of the screen at every launch is worse than letting the
            // platform place it.
            .onCreated {
                window.title = "StateUI Gallery"
                window.width = 1100
                window.height = 800
                dress(window)
                window.minimumWidth = 700
                window.minimumHeight = 500
                window.maximumWidth = 1600
                window.maximumHeight = 1200
                window.isMaximizable = true
                window.isMinimizable = true

                // On a desktop the menu stands beside the page, so choosing a
                // row leaves it open.
                if device.info.formFactor == .desktop {
                    nav.menuOverlays = false
                }

                log.note("created")
            }
            // The Appearance sample changes the look while the window stands.
            .onChanged(style.windows) { dress(window) }
            .onChanged(style.windowColour) { dress(window) }
            // listing: end
        // listing: MainPage.modal
        } destination: { _ in
            ModalPage(nav: nav)
        }
        // listing: end
    }

    // listing: MainPage.detail
    /// The other half of the split view: the section, arranged the way that section
    /// wants to be.
    ///
    /// Almost always a STACK - a `NavigationStack` over the path, with the
    /// section's own page underneath. The tabs demonstration is the exception,
    /// and it is the reason this is a function rather than one expression: a
    /// `TabView` is a page like any other, so a section may simply be one -
    /// and a stack may sit inside one of its tabs.
    @ViewBuilder
    func detail() -> some View {
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
    // listing: end

    /// The page under everything, for the section the menu chose.
    ///
    /// HOME is the root of the main stack and a group is PUSHED onto it - see
    /// `Navigation.openGroup` - so this answers three sections rather than a
    /// group each. The user's way back out of anything is therefore the
    /// platform's own back button, all the way to the run of group cards the
    /// gallery opens with.
    @ViewBuilder
    func root() -> some View {
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
    @ViewBuilder
    func page(for route: Route, path: Binding<[Route]>) -> some View {
        switch route {
        case .group(let route):
            if let group = catalog.groups.first(where: { $0.route == route }) {
                GroupPage(group: group, nav: nav)
            } else {
                MissingPage(id: route, nav: nav, path: path)
            }

        case .sample(let id):
            if let sample = catalog.sample(id: id) {
                SamplePage.shown(sample, nav: nav, style: style)
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

    // listing: MainPage.tabs
    /// The one section that is not a stack: a `TabView` over a list of the
    /// author's own enum, with a stack inside its `.stack` tab.
    func tabs() -> some View {
        TabView(nav.tabs) { which in
            switch which {
            case .stack:
                NavigationStack(nav.$tabsPath) {
                    TabsPage(nav: nav, path: nav.$tabsPath)
                } destination: { route in
                    page(for: route, path: nav.$tabsPath)
                }
                // A tab's caption and picture are what its page says, and this
                // tab's page is the stack rather than the page inside it - so
                // they are written on the stack.
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
    // listing: end

    // MARK: - The window's own look

    /// Dresses `window` as the gallery's look says: whether the desktop shows
    /// through it, and what it shows behind its pages.
    private func dress(_ window: WindowSession) {
        window.isTranslucent = style.windows.isTranslucent
        window.background = style.windows.background(in: style.windowColour)
    }
}
