import StateUI

/// What the gallery's window says on its bar, written by the sample and declared by the window.
final class WindowBarState {
    /// The line under the bar's title.
    @State var subtitle = ""

    /// Whether the window's bar carries "Surprise me" on every page.
    @State var showsSurprise = false
}

/// The bar the window declares on its page: the application's name, a line under the title, and an action on every
/// page.
struct WindowBarSample: SampleContent, ExampleContent {
    /// The values shared with the gallery window the sample is in.
    let bar: WindowBarState

    static let id = "windowBar"
    static let title = "Window bar"
    static let summary = "Type a line for the bar, then turn on an action every page carries."

    static let code = """
        final class WindowBarState {
            @State var subtitle = ""
            @State var showsSurprise = false
        }

        // Gallery/MainPage.swift - the window's page says what its bar carries,
        // whatever page the menu opens beside it.
        struct MainPage: View {
            @Environment(\\.device) private var device

            let catalog: Catalog
            let nav: Navigation
            let log: WindowLog
            let bar: WindowBarState

            var body: some View {
                SplitView(nav.$menuOpen) {
                    MenuPage(catalog: catalog, nav: nav, log: log, listsHiddenRow: nav.listsHiddenRow)
                } detail: {
                    HomePage(catalog: catalog, nav: nav)
                }
                .toolbar(id: "gallery") {
                    if bar.showsSurprise {
                        ToolbarItem("Surprise me")
                            .icon("nav_surprise_chrome.png")
                            .onClicked { nav.surprise(from: catalog, on: device.info.formFactor) }
                    }
                }
                .barTitle("StateUI")
                .barSubtitle(bar.subtitle)
                .barIcon("stateui_mark.png")
            }
        }

        let bar: WindowBarState

        VStack {
            TextField(bar.$subtitle)
                .placeholder("Window subtitle")

            HStack {
                Switch(bar.$showsSurprise)
                Text("Surprise me on every page")
            }
        }
        """

    var notes: (any View)? { nil }

    var body: some View {
        VStack {
            TextField(bar.$subtitle)
                .accessibilityIdentifier("windowBar.subtitle")
                .accessibilityLabel("Subtitle for the window")
                .placeholder("Window subtitle")

            HStack {
                Switch(bar.$showsSurprise)
                    .accessibilityIdentifier("windowBar.surprise")
                    .accessibilityLabel("Show an action on every page")

                Text("Surprise me on every page")
                    .verticalAlignment(.center)
            }
            .spacing(8)
        }
        .spacing(12)
    }
}
