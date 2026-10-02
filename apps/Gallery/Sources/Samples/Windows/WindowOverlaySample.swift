import StateUI

/// Notices laid over the window: one the window declares, standing over every page, and one this page declares,
/// going with it.
struct WindowOverlaySample: SampleContent, ExampleContent {
    /// Where the gallery is: the window's notice is its state.
    let nav: Navigation

    /// Whether this page's own notice stands over the window.
    @State private var onThisPage = false

    static let id = "windowOverlay"
    static let title = "Window overlay"
    static let summary = "Lay a notice over the window, then open another page."

    static let code = """
        // The window's page declares its own, over every page.
        struct MainWindow: Window {
            @State private var notice = false

            var page: any Page {
                Pages(notice: $notice)
                    .overlays {
                        if notice {
                            WindowNotice(words: "Over every page", shown: $notice)
                        }
                    }
            }
        }

        // A page declares one that goes with it.
        @Binding var notice: Bool
        @State private var onThisPage = false

        var body: some View {
            VStack {
                HStack {
                    Switch($notice)
                    Text("Over every page")
                }
                HStack {
                    Switch($onThisPage)
                    Text("Over this page")
                }
            }
            .overlays {
                if onThisPage {
                    WindowNotice(words: "Over this page", shown: $onThisPage)
                        .verticalAlignment(.end)
                }
            }
        }
        """

    var notes: (any View)? { nil }

    var body: some View {
        VStack {
            switchRow(nav.$windowNotice, "Over every page", id: "window.overlay")
            switchRow($onThisPage, "Over this page", id: "window.overlay.page")
        }
        .spacing(10)
        .overlays {
            if onThisPage {
                WindowNotice(words: "Over this page", shown: $onThisPage)
                    .verticalAlignment(.end)
            }
        }
    }

    /// A switch and what it says, told apart for scripts by `id`.
    private func switchRow(_ value: Binding<Bool>, _ words: String, id: String) -> HStack {
        HStack {
            Switch(value)
                .accessibilityIdentifier(id)
                .accessibilityLabel(words)
            Text(words).verticalAlignment(.center)
        }
        .spacing(8)
    }
}

/// A notice laid over the window: a line with its own way out, at the top unless it says otherwise.
struct WindowNotice: View {
    let words: String

    /// Whether it stands; its button takes it away.
    @Binding var shown: Bool

    var body: some View {
        HStack {
            Text(words)
                .textColor(.white)
                .verticalAlignment(.center)
            Button("Dismiss")
                .accessibilityIdentifier("window.overlay.dismiss")
                .onClicked { shown = false }
        }
        .spacing(12)
        .padding(horizontal: 16, vertical: 8)
        .background(Palette.accent)
        .shape(.roundedRectangle(10))
        .margin(12)
        .horizontalAlignment(.center)
        .verticalAlignment(.start)
    }
}
