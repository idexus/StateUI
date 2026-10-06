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
        // A notice: a line with its own way out, at the top unless it says
        // otherwise.
        struct WindowNotice: View {
            let words: String
            @Binding var shown: Bool

            var body: some View {
                HStack {
                    Text(words)
                    Button("Dismiss").onClicked { shown = false }
                }
                .horizontalAlignment(.center)
                .verticalAlignment(.start)
            }
        }

        // Gallery/MainPage.swift - the window's page declares its own, over
        // every page.
        struct MainPage: View {
            let catalog: Catalog
            let nav: Navigation
            let log: WindowLog

            var body: some View {
                SplitView(nav.$menuOpen) {
                    MenuPage(catalog: catalog, nav: nav, log: log, listsHiddenRow: nav.listsHiddenRow)
                } detail: {
                    HomePage(catalog: catalog, nav: nav)
                }
                .overlays {
                    if nav.windowNotice {
                        WindowNotice(words: "Over every page", shown: nav.$windowNotice)
                    }
                }
            }
        }

        // A page declares one that goes with it.
        let nav: Navigation
        @State private var onThisPage = false

        VStack {
            HStack {
                Switch(nav.$windowNotice)
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
