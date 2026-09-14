import StateUI

/// A native modal stack owned by application state.
struct ModalSample: SampleContent {
    let nav: Navigation

    static let id = "modal"
    static let title = "Presenting over everything"
    static let summary = "One array drives the platform's native modal stack."

    static let code = """
        enum Sheet: Hashable {
            case settings
        }

        struct MainWindow: Window {
            @State private var sheets: [Sheet] = []

            var page: any View {
                HomePage(sheets: $sheets)
            }
        }

        struct HomePage: ContentView {
            @Environment private var window: WindowSession
            @Binding var sheets: [Sheet]

            var content: any View {
                VStack {
                    DebugInfoLabel()

                    Button("Present")
                        .onClicked { sheets.append(.settings) }
                        .onCreated {
                            window.modalStack = ModalStack($sheets) { _ in
                                SettingsPage(sheets: $sheets)
                            }
                        }
                }
            }
        }

        struct SettingsPage: ContentView {
            @Binding var sheets: [Sheet]

            var content: any View {
                Button("Close")
                    .onClicked { sheets.removeLast() }
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Button("Present native modal")
                .automationId("modal.present")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.present(.page) }

            Label(nav.sheets.isEmpty ? "Nothing presented" : "Depth: \(nav.sheets.count)")
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
        }
        .spacing(12)
    }
}
