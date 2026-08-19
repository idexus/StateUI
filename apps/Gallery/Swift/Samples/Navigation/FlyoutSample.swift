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
        Button(menuOpen ? "Close the menu" : "Open the menu")
            .onClicked { menuOpen.toggle() }

        Switch($listsHiddenRow)

        Button("Go there anyway")
            .onClicked { nav.open(.hidden) }
        """

    var content: Element {
        VStack {
            Label("Open the menu: every row you see is a view this app wrote.")
                .fontSize(14)

            Label("A Shell's flyout is a list the library describes - items with routes, "
                + "a template run over them, a header slot, a footer slot, a selection "
                + "MAUI decides, and a MenuItem type for a row that merely does something. "
                + "None of that is here. The pane is a ContentPage: a gradient at the top, "
                + "rows in the middle, a line at the bottom.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("So a row is a view with a tap on it, and what it does is write state - "
                + "\"show this section\" and \"close the menu\", in the order this app "
                + "wants. A row that should leave the menu open simply does not write the "
                + "second one. There is no rule about it to learn.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Which row is the one you are ON is this app's answer too, because it "
                + "holds the section: `nav.showing(.home)`. In MAUI's Shell the framework "
                + "selects the row and a visual state says what that means.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("OPENING IT")

            Button(nav.menuOpen ? "Close the menu" : "Open the menu")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.menuOpen.toggle() }

            Label("`FlyoutPage($menuOpen)` is two-way: this button opens it, the swipe "
                + "that shuts it writes `false` back, and so does a tap outside the pane. "
                + "MAUI gives IsPresented no event of its own, so the host watches it - "
                + "the way it watches IsFocused and ScrollY.")
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

            Label("In MAUI's Shell, `flyoutItemIsVisible` is a property on an item the "
                + "framework holds. Here "
                + "the list is a view, so the answer is `if` - and the page is reachable "
                + "either way, because `.hidden` is a value and a value nobody drew a row "
                + "for is still a value.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("On a wide screen MAUI can split the window instead of sliding a drawer "
                + "over it - `.flyoutLayoutBehavior(.split)` asks for that - and it then "
                + "REFUSES to close the pane, throwing from the property. The host catches "
                + "that refusal and reports it, so the binding ends up saying `true` and "
                + "the app is never lied to. This gallery asks for `.popover`, which is a "
                + "drawer everywhere.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
