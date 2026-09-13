import StateUI

/// Values changed by the sample and presented by the gallery window.
final class TitleBarState {
    /// The second line in the native title area.
    @State var subtitle = ""

    /// Whether the trailing title-area slot presents an action.
    @State var showsSurprise = false
}

/// Native window chrome described by a `TitleBar` value and its three slots.
struct TitleBarSample: SampleContent {
    /// The values shared with this gallery's main window.
    let bar: TitleBarState

    static let id = "titleBar"
    static let title = "TitleBar"
    static let summary = "Title, color, and interactive content in native window chrome."
    static let idioms: Set<DeviceIdiom> = [.desktop]

    static let code = """
        final class TitleBarState {
            @State var subtitle = ""
            @State var showsAction = false
        }

        struct MainWindow: Window {
            let titleBar: TitleBarState
            @Environment private var window: WindowSession

            var page: any Page {
                HomePage()
                    .onCreated { window.titleBar = chrome }
                    .onChanged(titleBar.subtitle) {
                        window.titleBar = chrome
                    }
            }

            var chrome: TitleBar {
                TitleBar("StateUI")
                    .subtitle(titleBar.subtitle)
                    .icon("stateui_mark.png")
                    .foregroundColor(.white)
                    .backgroundColor(.cornflowerBlue)
                    .leadingContent { Button("Sidebar") }
                    .content { SearchBar("Search") }
                    .trailingContent {
                        TitleBarAction(state: titleBar)
                    }
            }
        }

        struct TitleBarAction: ContentView {
            let state: TitleBarState

            var content: any View {
                HStack {
                    if state.showsAction {
                        Button("Surprise me")
                    }
                }
            }
        }

        struct TitleBarSample: ContentView {
            let state: TitleBarState

            var content: any View {
                VStack {
                    DebugInfoLabel()
                    Entry(state.$subtitle).placeholder("Window subtitle")
                    Switch(state.$showsAction)
                }
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Entry(bar.$subtitle)
                .automationId("titleBar.subtitle")
                .semanticDescription("Subtitle for the window")
                .placeholder("Window subtitle")

            HStack {
                Switch(bar.$showsSurprise)
                    .automationId("titleBar.surprise")
                    .semanticDescription("Show a title bar action")

                Label("Show a trailing action")
                    .verticalOptions(.center)
            }
            .spacing(8)
        }
        .spacing(12)
    }
}
