import StateUI

/// MAUI: FlyoutPage - and the menu it holds, which is an ordinary page.
struct FlyoutSample: SampleContent {
    /// Where the gallery is: this sample opens and closes the menu, and sends
    /// the reader to the section the menu does not always list.
    let nav: Navigation

    /// Whether the menu lists the row that is hidden by default. The
    /// APPLICATION's state, lent here - the same way `nav` is.
    @Binding var listsHiddenRow: Bool

    static let id = "flyout"
    static let title = "Flyout and menu"
    static let summary = "The menu you are looking at is a page, and every row in it is a view."

    static let code = """
        @State private var menuOpen = false
        @State private var menuGesture = true
        @State private var listsHiddenRow = false
        @State private var path: [Route] = []

        // The arrangement, in GalleryApp.swift:
        FlyoutPage($menuOpen) {
            MenuPage(catalog: catalog, nav: nav, listsHiddenRow: listsHiddenRow)
        } detail: {
            NavigationPage($path) {
                root(catalog, nav)
            } destination: { route in
                page(for: route, catalog, nav, path: $path)
            }
        }
        .flyoutLayoutBehavior(.popover)
        .isGestureEnabled(menuGesture)

        // -- AND THE MENU IS A PAGE --

        struct MenuPage: ContentPage {
            var title: String? { "StateUI" }    // REQUIRED: MAUI refuses a
                                                  // flyout page without one
            var content: Element {
                VStack {
                    MenuRow("Home") { nav.open(.home) }   // choose, and close:
                        .icon(home)                       // two writes, in
                        .chosen(nav.showing(.home))       // this order

                    // A row the menu lists only when it is told to. The page
                    // behind it is reachable either way.
                    if listsHiddenRow {
                        MenuRow("Not in the list") { nav.open(.hidden) }
                            .icon(hidden)
                    }
                }
            }
        }

        // And on this page, which borrows the same bindings:
        SwitchRow("Menu open", $menuOpen)

        // The switch above is unaffected by this: it writes the state directly.
        Switch($menuGesture)

        Switch($listsHiddenRow)

        Button("Go there anyway")
            .onClicked { nav.open(.hidden) }
        """

    var example: Element {
        VStack {
            Label("Open the menu: every row you see is a view this app wrote.")
                .fontSize(14)

            SectionTitle("OPENING IT")

            SwitchRow("Menu open", nav.$menuOpen)
                .horizontalOptions(.center)

            SectionTitle("AND WHETHER THE SWIPE OPENS IT")

            HStack {
                Switch(nav.$menuGesture)

                Label(nav.menuGesture
                    ? "Swipe from the left edge: the menu follows your finger"
                    : "Swipe from the left edge: nothing happens")
                    .fontSize(14)
                    .verticalOptions(.center)
            }
            .spacing(10)

            Label("The switch above keeps working either way - it writes the state itself, "
                + "and only the finger is being turned off.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("A ROW THAT IS NOT LISTED")

            HStack {
                Switch($listsHiddenRow)

                Label(listsHiddenRow
                    ? "The menu lists \"Not in the list\""
                    : "The menu does not list it")
                    .fontSize(14)
                    .verticalOptions(.center)
            }
            .spacing(10)

            Button("Go there anyway")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.open(.hidden) }
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("The pane is an ordinary ContentPage - a gradient at the top, rows in "
                + "the middle, a line at the bottom - and every row is a view with a tap "
                + "on it. What a row DOES is write state: \"show this section\" and "
                + "\"close the menu\", in the order this app wants. A row that should "
                + "leave the menu open simply does not write the second one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Which row you are ON is this app's answer too, because this app holds "
                + "the section: `nav.showing(.home)` is what draws a row as the current "
                + "one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Whether a row is listed at all is an `if`, because the list is a view. "
                + "The page behind it stays reachable either way - `.hidden` is a value, "
                + "and a value nobody drew a row for is still a value.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`FlyoutPage($menuOpen)` is two-way: the switch opens it, and the swipe "
                + "that shuts it writes `false` back, as does a tap outside the pane.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`isGestureEnabled` is the swipe alone. The gesture is the platform's, so "
                + "where there is none to begin with - a desktop window with no touch "
                + "screen - `false` takes away nothing that was there.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.flyoutLayoutBehavior(.split)` asks for the pane to sit beside the "
                + "page on a wide screen instead of sliding over it. A split pane cannot "
                + "be closed, so the binding stays `true` there. This gallery asks for "
                + "`.popover`, which is a drawer everywhere.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
