import StateUI

/// A gallery's main window: what it is called, how big it opens, what is
/// presented over it - and THE ARRANGEMENT, which is the reason this is a type
/// of its own.
///
/// A window is where an application says what a screenful IS, so everything
/// about the way the gallery moves lives here: the flyout holding the menu and
/// the section, the stack the sections push onto, the tabs that one section is
/// arranged as, and the modal stack over all of it. `GalleryScene` next door is
/// then what it should be - the gallery's state, and the windows built from it.
///
/// **The arrangement is one page with a menu on one side and whatever the
/// section asks for on the other.**
/// Nothing here is a route string, nothing is asked of MAUI and nothing has to
/// be awaited: a move is an assignment. See Gallery/Navigation.swift for the
/// types and the moves.
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

    /// THE ARRANGEMENT, and it is three ordinary values: a flyout holding two
    /// pages, a stack holding an array, a set of tabs holding a selection.
    var page: any Page {
        FlyoutPage(nav.$menuOpen) {
            MenuPage(
                catalog: catalog,
                nav: nav,
                log: log,
                listsHiddenRow: nav.listsHiddenRow)
        } detail: {
            detail()
        }
        // A DRAWER on every screen size. Left to `.default`, a
        // wide window may split itself in two and keep the menu open beside the
        // page - and MAUI then refuses to close it, which is a sample in its own
        // right rather than the way an app should open.
        .flyoutLayoutBehavior(.popover)
        // Whether the EDGE SWIPE reaches the menu. The buttons that write
        // `menuOpen` are unaffected either way - see `FlyoutSample`, which is
        // where the switch that writes this lives.
        .isGestureEnabled(nav.menuGesture)
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
            window.isMaximizable = true
            window.isMinimizable = true

            // The window's own chrome, written only where there is a window
            // to dress: `WindowHandler.MapTitleBar` has a body on Mac
            // Catalyst and Windows and nowhere else, so a phone is simply
            // not asked.
            if device.idiom == .desktop {
                window.titleBar = chrome
            }

            // What is over all of it: a second arranged list on the window,
            // holding the pages presented over the flyout, the stack and the
            // bars alike. Written once - it reads the array as the window
            // builds - and empty almost always: presenting is
            // `sheets.append`, and a sheet the reader drags down truncates
            // the array itself.
            window.modalStack = ModalStack(nav.$sheets) { sheet in
                switch sheet {
                case .page(let style): ModalPage(nav: nav, style: style)
                case .card: CardSheetPage(nav: nav)
                }
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
    }

    /// The other half of the flyout: the section, arranged the way that section
    /// wants to be.
    ///
    /// Almost always a STACK - a `NavigationPage` over the path, with the
    /// section's own page underneath. The tabs demonstration is the exception,
    /// and it is the reason this is a function rather than one expression: a
    /// `TabbedPage` is a page like any other, so a section may simply be one -
    /// and a stack may sit inside a tab, because pages nest without a rule
    /// about which may hold which.
    func detail() -> Page {
        if case .tabs = nav.section {
            return tabs()
        }

        return NavigationPage(nav.$path) {
            root()
        } destination: { route in
            page(for: route, path: nav.$path)
        }
        // The bar belongs to the ARRANGEMENT, not to a page on it - which is
        // MAUI's own model (IBarElement) and this library's tier. The gallery's
        // accent in BOTH themes: everything on this bar is white, so the bar
        // cannot be the half that goes pale.
        .barBackgroundColor(style.accent.color)
        .barTextColor(Palette.onBrand)
    }

    /// The page under everything, for the section the menu chose.
    ///
    /// HOME is the root of the main stack and a group is PUSHED onto it - see
    /// `Navigation.openGroup` - so this answers three sections rather than a
    /// group each. The reader's way back out of anything is therefore the
    /// platform's own back button, all the way to the page the gallery opens
    /// with.
    func root() -> Page {
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
    func page(for route: Route, path: Binding<[Route]>) -> Page {
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

            return SamplePage(sample: sample, nav: nav)

        case .level(let level):
            return LevelPage(level: level, nav: nav, path: path)

        case .item(let item):
            return ItemPage(item: item, nav: nav, path: path)
        }
    }

    /// The one section that is not a stack: a `TabbedPage` over the author's own
    /// enum, with a stack inside the first tab.
    ///
    /// Its own bar colours, because a TabbedPage has a bar of its own - the same
    /// three properties, from the same tier.
    func tabs() -> Page {
        TabbedPage(nav.tabs) { which in
            switch which {
            case .stack:
                return NavigationPage(nav.$tabsPath) {
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
        .selectedTabColor(Palette.accent)
        .unselectedTabColor(Palette.subtle)
        // A BRUSH rather than a colour, which is the difference between this
        // bar and every other bar in the app: `barBackgroundColor` takes one
        // flat colour, `barBackground` takes anything a Brush can be. See
        // TabsSample, which is the page underneath it.
        .barBackground(.linearGradient([
            GradientStop(style.accent.color, 0),
            GradientStop(Palette.accent, 1),
        ], startPoint: Point(0, 0), endPoint: Point(1, 0)))
        .barTextColor(Palette.onBrand)
    }

    // MARK: - The window's own chrome

    /// The desktop's title bar: the mark, the name, and whatever the TitleBar
    /// sample asked for - its subtitle and its trailing button live in
    /// `bar`, which the sample writes and this reads. See
    /// Samples/Windows/TitleBarSample.swift.
    ///
    /// The LOOK is built in the slots rather than with MAUI's
    /// Title/Subtitle/Icon: the template draws those at the system's size -
    /// small letters, a mark a few points wide - while a slot is an ordinary
    /// view this app can size and colour. The bar is painted in the gallery's
    /// accent, like the navigation bar under it, so the two read as one piece
    /// of chrome - and neither follows the theme.
    private var chrome: TitleBar {
        // No .heightRequest here, measured: the platform draws the strip at its
        // own height, and a taller request is RESERVED in the layout anyway -
        // what filled the difference was a black band under the bar, across the
        // menu and the page alike.
        // The mark and the WORDS go to the far end - the left of a Mac window
        // already has three buttons and the menu's own header under it - and
        // the leading slot holds the menu button alone.
        TitleBar()
            .backgroundColor(style.accent.color)
            .foregroundColor(Palette.onBrand)
            // The `if` stands in the SLOT, with no stack around it to give it a
            // home: a slot takes a builder like every other nested content, so
            // the branch is identified and a slot that produces nothing is
            // emptied rather than left holding a stack with nothing in it.
            //
            // The branch asks about the PLATFORM alone. Whether there is a page
            // to go back from is answered by the button's OPACITY, because the
            // strip is as tall as what stands in it and a slot that empties
            // shortens the bar - measured on Catalyst: 76 points of chrome on
            // the home page against 84 on a pushed one, so it jumped by eight
            // at every push and every pop. A view at zero opacity is still
            // measured, which holds the height still, and `inputTransparent`
            // is what keeps the invisible one from being pressed.
            .leadingContent {
                if device.platform == "MacCatalyst" {
                    ChromeMenu(nav: nav)
                }
            }
            // THE BAR IS WRITTEN INTO THE WINDOW'S SESSION - once, and again
            // when the accent moves - and what stands in its slots is built
            // where the bar is shown, so the parts that follow the gallery's
            // state are VIEWS OF THEIR OWN, reading it as they build: the
            // button's opacity follows the path, the words at the far end the
            // TitleBar sample.
            .trailingContent {
                ChromeEnd(bar: bar, nav: nav, catalog: catalog)
            }
    }
}

/// The menu button in the window's chrome - a view of its own, so it reads the
/// path as it builds and is built again when a page is pushed or popped: the
/// title bar holding it is not written again for that.
///
/// Whether there is a page to go back from is answered by the button's
/// OPACITY rather than by leaving it out, because the strip is as tall as what
/// stands in it and a slot that empties shortens the bar - measured on
/// Catalyst: 76 points of chrome on the home page against 84 on a pushed one,
/// so it jumped by eight at every push and every pop. A view at zero opacity is
/// still measured, which holds the height still, and `inputTransparent` is what
/// keeps the invisible one from being pressed.
private struct ChromeMenu: ContentView {
    /// Where the gallery is - the path the button follows, and the menu it
    /// opens.
    let nav: Navigation

    var content: any View {
        ImageButton("nav_menu_dark.png")
            // A PICTURE AND NOTHING ELSE, which is exactly the control that has
            // to say what it is. The flyout's own toggle is drawn by MAUI in the
            // leading slot of the stack's root and answers to the platform's
            // own name; this is the one the window's chrome carries.
            .automationId("chrome.menu")
            .semanticDescription("Menu")
            .semanticHint("Opens the list of sample groups")
            .padding(10)
            .margin(20, 0)
            .verticalOptions(.center)
            .opacity(nav.path.count > 0 ? 1 : 0)
            .inputTransparent(nav.path.count == 0)
            .onClicked { nav.menuOpen.toggle() }
    }
}

/// The far end of the window's chrome: the mark, the name, and what the
/// TitleBar sample asked for - read here, so the words and the chip follow
/// the sample's state while the bar around them stands. See
/// Samples/Windows/TitleBarSample.swift.
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
            // WHITE, the colour of the name beside it: the mark and the
            // application's name are one thing said twice, and the
            // accent is left to the one thing up here that can be
            // pressed.
            HStack {
                Image("stateui_mark.png")
                    .widthRequest(26)
                    .heightRequest(26)
                    .margin(12, 0, 0, 0)
                    .verticalOptions(.center)

                Label("StateUI")
                    .fontSize(16)
                    .fontAttributes(.bold)
                    .textColor(Palette.onBrand)
                    .verticalOptions(.center)
            }
            .padding(4)
            .spacing(4)

            // Written even when empty: an empty subtitle is an empty label.
            Label(bar.subtitle)
                .fontSize(15)
                .textColor(Palette.onBrand)
                .opacity(0.85)
                .verticalOptions(.center)

            // One slot holds both: MAUI gives a title bar three, and a
            // second thing at the same end would have nowhere to go.
            // The menu's own "Surprise me" row, as a chip in the chrome:
            // the same icon, the same act - in the CHROME artwork, which
            // is that icon in the colour of the words beside it. One
            // file rather than a themed pair, the bar being the accent
            // in either theme.
            //
            // A Button rather than a Border with a tap on it - measured
            // on Catalyst: a Border in a title bar slot paints its
            // background and NOT its content, so the chip came out an
            // empty pill.
            if bar.showsSurprise {
                Button("Surprise me")
                    .imageSource("nav_surprise_chrome.png")
                    .contentLayout(.left, spacing: 5)
                    .style("ChromeChip")
                    .verticalOptions(.center)
                    .onClicked { nav.surprise(from: catalog, on: device.idiom) }
            }
        }
        .spacing(12)
        // Off the window's edge: a control butted against the glass
        // reads as clipped, and the mark on the far side keeps the same
        // distance.
        .margin(0, 0, 5, 0)

    }
}
