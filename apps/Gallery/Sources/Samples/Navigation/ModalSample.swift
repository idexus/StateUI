import StateUI

/// A native modal stack owned by application state.
struct ModalSample: SampleContent, ExampleContent {
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

            // The sheets stand over the window's page, the last on top.
            var page: any Page {
                ModalStack($sheets) {
                    HomePage(sheets: $sheets)
                } destination: { _ in
                    SettingsPage(sheets: $sheets)
                }
            }
        }

        struct HomePage: ContentView {
            @Binding var sheets: [Sheet]

            var content: some View {
                VStack {
                    DebugInfoLabel()

                    Button("Present")
                        .onClicked { sheets.append(.settings) }
                }
            }
        }

        struct SettingsPage: ContentView {
            @Binding var sheets: [Sheet]

            var content: some View {
                Button("Close")
                    .onClicked { sheets.removeLast() }
            }
        }
        """

    var notes: (any View)? { nil }

    var content: some View {
        VStack {
            DebugInfoLabel()

            Button("Present native modal")
                .accessibilityIdentifier("modal.present")
                .background(Palette.accent)
                .textColor(.white)
                .shape(.roundedRectangle(8))
                .padding(20, 10)
                .horizontalAlignment(.center)
                .onClicked { nav.present(.page) }

            Text(nav.sheets.isEmpty ? "Nothing presented" : "Depth: \(nav.sheets.count)")
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
        }
        .spacing(12)
    }
}
