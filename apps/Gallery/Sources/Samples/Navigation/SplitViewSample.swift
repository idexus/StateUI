import StateUI

/// A native split view whose sidebar is an ordinary StateUI page.
struct SplitViewSample: SampleContent, ExampleContent {
    // listing: SplitViewSample
    /// Where the gallery is: this sample opens and closes the menu, and sends
    /// the user to the section the menu does not always list.
    let nav: Navigation
    // listing: end

    static let id = "splitview"
    static let title = "Split view and menu"
    static let summary = "The menu you are looking at is a page, and every row in it is a view."

    static var code: String { Listings.joined("MainPage.split", "MenuPage", "SplitViewSample") }

    // listing: SplitViewSample
    var body: some View {
        VStack {
            Text("Open the menu: every row in it is a view.")
                .fontSize(14)

            SwitchRow("Menu open", nav.$menuOpen)
                .horizontalAlignment(.center)

            HStack {
                Switch(nav.$listsHiddenRow)
                    .accessibilityIdentifier("splitview.hiddenRow")
                    .accessibilityLabel("Show the row that is not in the list")

                Text(nav.listsHiddenRow
                    ? "The menu lists \"Not in the list\""
                    : "The menu does not list it")
                    .fontSize(14)
                    .verticalAlignment(.center)
            }
            .spacing(10)

            Button("Go there anyway")
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .onClicked { nav.open(.hidden) }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The pane is an ordinary page. Every row is a view whose action writes "
                + "where the gallery goes - closing the menu where it lies over the page - "
                + "and a row the app does not want is an `if` around it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`SplitView($menuOpen)` is two-way. The native host adapts the pane; "
                + "when it keeps both sides visible, the binding settles on `true`.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
