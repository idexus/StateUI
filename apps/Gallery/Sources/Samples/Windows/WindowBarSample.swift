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
    /// The values shared with this gallery's main window.
    let bar: WindowBarState

    static let id = "windowBar"
    static let title = "Window bar"
    static let summary = "Type a line for the bar, then turn on an action every page carries."

    static let code = """
        final class WindowBarState {
            @State var subtitle = ""
            @State var showsAction = false
        }

        struct MainWindow: Window {
            let bar: WindowBarState
            @State private var showsMenu = true

            var page: any Page {
                SplitView($showsMenu) {
                    MenuPage()
                } detail: {
                    HomePage()
                }
                .barTitle("StateUI")
                .barSubtitle(bar.subtitle)
                .barIcon("stateui_mark.png")
                .toolbar {
                    if bar.showsAction {
                        ToolbarItem("Surprise me")
                            .icon("surprise.png")
                    }
                }
            }
        }

        struct WindowBarSample: ContentView {
            let bar: WindowBarState

            var content: some View {
                VStack {
                    TextField(bar.$subtitle)
                        .placeholder("Window subtitle")
                    Switch(bar.$showsAction)
                }
            }
        }
        """

    var notes: (any View)? { nil }

    var content: some View {
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
