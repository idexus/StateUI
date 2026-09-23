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
        // The arrangement, in Gallery/MainWindow.swift - over the gallery's
        // own `Navigation`, a class of states:
        SplitView(nav.$menuOpen) {
            MenuPage(catalog: catalog, nav: nav, log: log,
                     listsHiddenRow: nav.listsHiddenRow)
        } detail: {
            NavigationStack(nav.$path) {
                root()
            } destination: { route in
                page(for: route, path: nav.$path)
            }
        }

        // The menu is a page of its own:
        struct MenuPage: ContentView {
            let catalog: Catalog
            let nav: Navigation
            let log: WindowLog
            let listsHiddenRow: Bool

            @Environment private var device: DeviceInfo
            @Environment private var page: PageSession

            var content: any View {
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
                    MenuRow("Surprise me") { nav.surprise(from: catalog, on: device.formFactor) }
                        .icon(ImageSource(light: "nav_surprise.png", dark: "nav_surprise_dark.png"))

                    // The window's phase, written into its log by a view of
                    // its own - so a phase change builds that and nothing else.
                    WindowPhaseLog(log: log)
                }
                .onCreated { page.title = "StateUI" }
            }
        }

        // And on this page, which reads the same states:
        SwitchRow("Menu open", nav.$menuOpen)

        Switch(nav.$listsHiddenRow)

        Button("Go there anyway")
            .onClicked { nav.open(.hidden) }
        """

    var content: any View {
        VStack {
            Label("Open the menu: every row in it is a view.")
                .fontSize(14)

            SwitchRow("Menu open", nav.$menuOpen)
                .horizontalAlignment(.center)

            HStack {
                Switch(nav.$listsHiddenRow)
                    .accessibilityIdentifier("splitview.hiddenRow")
                    .accessibilityLabel("Show the row that is not in the list")

                Label(nav.listsHiddenRow
                    ? "The menu lists \"Not in the list\""
                    : "The menu does not list it")
                    .fontSize(14)
                    .verticalAlignment(.center)
            }
            .spacing(10)

            Button("Go there anyway")
                .padding(20, 10)
                .horizontalAlignment(.center)
                .onClicked { nav.open(.hidden) }
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("The pane is an ordinary page. Every row is a view whose action chooses "
                + "a section and closes the menu, and a row the app does not want is an "
                + "`if` around it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`SplitView($menuOpen)` is two-way. The native host adapts the pane; "
                + "when it keeps both sides visible, the binding settles on `true`.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
