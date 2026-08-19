import StateUI

/// The gallery's own window: what it is called, how big it opens, what is
/// presented over it - and THE ARRANGEMENT, which is the reason this is a type
/// of its own.
///
/// A window is where an application says what a screenful IS, so everything
/// about the way the gallery moves lives here: the flyout holding the menu and
/// the section, the stack the sections push onto, the tabs that one section is
/// arranged as, and the modal stack over all of it. `GalleryApp` next door is
/// then what it should be - the state, and the list of windows built from it.
///
/// **Where MAUI's Shell is items, routes, templates and a registry, this is a
/// page with a menu on one side and whatever the section asks for on the
/// other.**
/// Nothing here is a route string, nothing is asked of MAUI and nothing has to
/// be awaited: a move is an assignment. See Gallery/Navigation.swift for the
/// types and the moves.
///
/// A pure function of what it is handed - the catalog, where the gallery is, the
/// tab's state and a way to log a lifecycle event - which is what lets a test
/// build the whole arrangement without reaching into a running application.
struct MainWindow: Window {
    /// Which kind of device this is, from the standard environment - answered by
    /// the host before the first render, so the first window build already knows
    /// whether to wear a title bar.
    @Environment private var device: DeviceInfo

    /// Every sample there is, already built.
    let catalog: Catalog

    /// Where the gallery is: the section, the path, the menu, the sheets, and
    /// the windows that are open.
    let nav: Navigation

    /// What that tab has pushed - its own array, which is what makes each tab
    /// keep its place.
    let tabsPath: Binding<[Route]>

    /// Whether the menu lists the row that is hidden by default - the
    /// application's, and read here because the menu is written here.
    let listsHiddenRow: Bool

    /// Writes one window lifecycle event into the application's log. The state
    /// is `GalleryApp`'s, the moments are this window's.
    let note: (String) -> Void

    // MARK: - The window itself

    /// A size and a minimum: the size is where it opens, the minimum is how
    /// small the reader may drag it before the layout stops making sense. A
    /// phone ignores both, an app there being the whole screen.
    ///
    /// No `x` or `y` on purpose - they exist, and pinning an app to the same
    /// corner of the screen at every launch is worse than letting the platform
    /// place it.
    var title: String? { "StateUI Gallery" }
    var width: Double? { 1100 }
    var height: Double? { 800 }
    var minimumWidth: Double? { 700 }
    var minimumHeight: Double? { 500 }

    // MAUI's Window events. created, stopped and resumed are the application's
    // OnStart, OnSleep and OnResume moments; the activated/deactivated pair
    // rides each trip to the background - NOT a mere focus switch on Mac
    // Catalyst, measured. The Lifecycle sample shows the log.
    var onCreated: EventHandler? { { note("created") } }
    var onActivated: EventHandler? { { note("activated") } }
    var onDeactivated: EventHandler? { { note("deactivated") } }
    var onStopped: EventHandler? { { note("stopped") } }
    var onResumed: EventHandler? { { note("resumed") } }
    var onDestroying: EventHandler? { { note("destroying") } }

    /// The window's own chrome, written only where there is a window to dress:
    /// `WindowHandler.MapTitleBar` has a body on Mac Catalyst and Windows and
    /// nowhere else, so a phone is simply not asked.
    var titleBar: TitleBar? {
        device.idiom == .desktop ? chrome : nil
    }

    /// What is over all of it: a second arranged list on the window, holding the
    /// pages presented over the flyout, the stack and the bars alike. Empty
    /// almost always - presenting is `sheets.append`, and a sheet the reader
    /// drags down truncates the array itself.
    var modalStack: ModalStack? {
        ModalStack(nav.$sheets) { sheet in
            switch sheet {
            case .page(let style): ModalPage(nav: nav, style: style)
            case .card: CardSheetPage(nav: nav)
            }
        }
    }

    // MARK: - What the reader is looking at

    /// THE ARRANGEMENT, and it is three ordinary values: a flyout holding two
    /// pages, a stack holding an array, a set of tabs holding a selection.
    var content: Page {
        FlyoutPage(nav.$menuOpen) {
            MenuPage(
                catalog: catalog,
                nav: nav,
                listsHiddenRow: listsHiddenRow,
                surprise: { surprise() })
        } detail: {
            detail()
        }
        // A DRAWER on every screen size - what a Shell spells
        // `.flyoutBehavior(.flyout)`. Left to `.default`, a
        // wide window may split itself in two and keep the menu open beside the
        // page - and MAUI then refuses to close it, which is a sample in its own
        // right rather than the way an app should open.
        .flyoutLayoutBehavior(.popover)
    }

    /// The other half of the flyout: the section, arranged the way that section
    /// wants to be.
    ///
    /// Almost always a STACK - a `NavigationPage` over the path, with the
    /// section's own page underneath. The tabs demonstration is the exception,
    /// and it is the reason this is a function rather than one expression: a
    /// `TabbedPage` is a page like any other, so a section may simply be one. A
    /// Shell cannot do this at all - a Tab there is shell STRUCTURE, declared
    /// beside the flyout items and reachable only by route.
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
        // MAUI's own model (IBarElement) and this library's tier. The .NET
        // violet in BOTH themes, not `Palette.brand`, which lightens in the
        // dark: everything on this bar is white, so the bar cannot be the half
        // that goes pale.
        .barBackgroundColor(AppColors.violet)
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
                return NavigationPage(tabsPath) {
                    TabsPage(nav: nav, path: tabsPath)
                } destination: { route in
                    page(for: route, path: tabsPath)
                }
                // A tab's caption and picture are the TAB PAGE's, and the tab
                // page here is the stack rather than what is inside it -
                // measured, and it is where the first live run showed no icons
                // at all.
                .title("Stack")
                .iconImageSource(ImageSource(light: "tab_bar.png", dark: "tab_bar_dark.png"))
                .barBackgroundColor(AppColors.violet)
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
        .barBackgroundColor(AppColors.violet)
        .barTextColor(Palette.onBrand)
    }

    // MARK: - The window's own chrome

    /// The desktop's title bar: the mark, the name, and whatever the TitleBar
    /// sample asked for - its subtitle and its trailing button live in
    /// `titleBarState`, which the sample writes and this reads. See
    /// Samples/Fundamentals/TitleBarSample.swift.
    ///
    /// The LOOK is built in the leading slot rather than with MAUI's
    /// Title/Subtitle/Icon: the template draws those at the system's size -
    /// small letters, a mark a few points wide - while a slot is an ordinary
    /// view this app can size and colour. The bar is painted the same violet as
    /// the navigation bar under it, so the two read as one piece of chrome -
    /// `AppColors.violet` directly, the GalleryPage exception said again: the
    /// bar must match the bar, and neither follows the theme.
    private var chrome: TitleBar {
        // No .heightRequest here, measured: the platform draws the strip at its
        // own height, and a taller request is RESERVED in the layout anyway -
        // what filled the difference was a black band under the bar, across the
        // menu and the page alike.
        // The mark sits beside the traffic lights and the WORDS go to the far
        // end - the left of a Mac window already has three buttons and the
        // menu's own header under it, and the right is empty.
        TitleBar()
            .backgroundColor(AppColors.violet)
            .foregroundColor(Palette.onBrand)
            // The `if` stands in the SLOT, with no stack around it to give it a
            // home: a slot takes a builder like every other nested content, so
            // the branch is identified and a slot that produces nothing is
            // emptied rather than left holding a stack with nothing in it.
            .leadingContent {
                if nav.path.count > 0 && device.platform == "MacCatalyst" {
                    ImageButton("nav_menu_dark.png")
                        .padding(10)
                        .margin(20, 0)
                        .verticalOptions(.center)
                        .onClicked { nav.menuOpen.toggle() }
                }
            }
            .trailingContent {
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

                    // Written even when empty, deliberately: a prop absent from
                    // a message is a prop that DID NOT CHANGE, so clearing the
                    // subtitle must send the empty string.
                    Label(titleBarState.subtitle)
                        .fontSize(15)
                        .textColor(Palette.onBrand)
                        .opacity(0.85)
                        .verticalOptions(.center)

                    // One slot holds both: MAUI gives a title bar three, and a
                    // second thing at the same end would have nowhere to go.
                    // The menu's own "Surprise me" row, as a chip in the chrome:
                    // the same icon, the same act - in the CHROME artwork, which
                    // is that icon in the colour of the words beside it. One
                    // file rather than a themed pair, the bar being violet in
                    // either theme.
                    //
                    // A Button rather than a Border with a tap on it - measured
                    // on Catalyst: a Border in a title bar slot paints its
                    // background and NOT its content, so the chip came out an
                    // empty pill.
                    if titleBarState.showsSurprise {
                        Button("Surprise me")
                            .imageSource("nav_surprise_chrome.png")
                            .contentLayout(.left, spacing: 5)
                            .style("ChromeChip")
                            .verticalOptions(.center)
                            .onClicked { surprise() }
                    }
                }
                .spacing(12)
                // Off the window's edge: a control butted against the glass
                // reads as clipped, and the mark on the far side keeps the same
                // distance.
                .margin(0, 0, 5, 0)
            }
    }

    /// Opens a sample nobody asked for - the menu's last row and the title bar's
    /// trailing button share it. Flattened, so every sample is as likely as
    /// every other - picking a group first would favour whatever is in the
    /// shortest one - and drawn from `shown`, so a phone is never surprised with
    /// a page about desktop chrome.
    ///
    /// Two assignments, where this was three awaited navigation calls: the menu
    /// closes and the page goes on the stack, and the next render is what moves
    /// the screen.
    private func surprise() {
        let idiom = device.idiom

        guard let sample = catalog.groups
            .flatMap({ $0.shown(on: idiom) })
            .randomElement()
        else { return }

        nav.menuOpen = false
        nav.push(.sample(sample.id))
    }
}
