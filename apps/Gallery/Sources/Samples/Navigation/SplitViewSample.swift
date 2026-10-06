import StateUI

/// A native split view whose sidebar is an ordinary StateUI page.
struct SplitViewSample: SampleContent, ExampleContent {
    /// Where the gallery is: this sample opens and closes the menu, and sends
    /// the user to the section the menu does not always list.
    let nav: Navigation

    static let id = "splitview"
    static let title = "Split view and menu"
    static let summary = "The menu you are looking at is a page, and every row in it is a view."

    static let code = """
        // Gallery/MainPage.swift - the arrangement, over the gallery's own
        // `Navigation`, a class of states. Beside the menu stands the page it
        // chose - in the gallery, a navigation stack.
        struct MainPage: View {
            let catalog: Catalog
            let nav: Navigation
            let log: WindowLog

            var body: some View {
                SplitView(nav.$menuOpen) {
                    MenuPage(catalog: catalog, nav: nav, log: log,
                             listsHiddenRow: nav.listsHiddenRow)
                } detail: {
                    HomePage(catalog: catalog, nav: nav)
                }
            }
        }

        // The menu is a page of its own:
        struct MenuPage: View {
            let catalog: Catalog
            let nav: Navigation
            let log: WindowLog
            let listsHiddenRow: Bool

            @Environment(\\.device) private var device

            var body: some View {
                VStack {
                    // Choose, then close: `open` writes the section and the
                    // path, then the menu.
                    MenuRow("Home") { nav.open(.home) }
                        .icon(ImageSource(light: "nav_home.png", dark: "nav_home_dark.png"))
                        .chosen(nav.showing(.home))

                    // One row per group, built from the catalog.
                    ForEach(catalog.groups, id: \\.route) { group in
                        MenuRow(group.title) { nav.openGroup(group.route) }
                            .icon(group.icon)
                            .chosen(nav.showingGroup(group.route))
                    }

                    // A row the menu lists only when it is told to. The page
                    // behind it is reachable either way.
                    if listsHiddenRow {
                        MenuRow("Not in the list") { nav.open(.hidden) }
                            .icon(ImageSource(light: "nav_hidden.png", dark: "nav_hidden_dark.png"))
                    }

                    // A row that DOES something rather than going somewhere.
                    MenuRow("Surprise me") { nav.surprise(from: catalog, on: device.info.formFactor) }
                        .icon(ImageSource(light: "nav_surprise.png", dark: "nav_surprise_dark.png"))

                    // The window's phase, written into its log by a view of
                    // its own - so a phase change builds that and nothing else.
                    WindowPhaseLog(log: log)
                }
                .title("StateUI")
            }
        }

        // And on this page, which reads the same states:
        let nav: Navigation

        VStack {
            Text("Open the menu: every row in it is a view.")

            SwitchRow("Menu open", nav.$menuOpen)

            HStack {
                Switch(nav.$listsHiddenRow)
                Text(nav.listsHiddenRow
                    ? "The menu lists \\\"Not in the list\\\""
                    : "The menu does not list it")
            }

            Button("Go there anyway")
                .onClicked { nav.open(.hidden) }
        }
        """

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

    var notes: (any View)? {
        VStack {
            Text("The pane is an ordinary page. Every row is a view whose action chooses "
                + "a section and closes the menu, and a row the app does not want is an "
                + "`if` around it.")
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
