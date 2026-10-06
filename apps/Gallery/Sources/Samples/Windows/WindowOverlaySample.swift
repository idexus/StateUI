import StateUI

/// Notices laid over the window: one the window declares, standing over every page, and one this page declares,
/// going with it.
struct WindowOverlaySample: SampleContent, ExampleContent {
    // listing: WindowOverlaySample
    /// Where the gallery is: the window's notice is its state.
    let nav: Navigation

    /// Whether this page's own notice stands over the window.
    @State private var onThisPage = false
    // listing: end

    static let id = "windowOverlay"
    static let title = "Window overlay"
    static let summary = "Lay a notice over the window, then open another page."

    static var code: String { Listings.joined("MainPage.overlays", "WindowOverlaySample") }

    var notes: (any View)? { nil }

    // listing: WindowOverlaySample
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
    // listing: end
}

// listing: WindowOverlaySample
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
// listing: end
