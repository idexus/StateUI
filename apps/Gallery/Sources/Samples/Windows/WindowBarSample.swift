import StateUI

// listing: WindowBarSample
/// What the gallery's window says on its bar, written by the sample and declared by the window.
@MainActor
final class WindowBarState {
    /// Whether the window's bar carries "Surprise me" on every page.
    @State var showsSurprise = false
}
// listing: end

/// The bar: an action the window declares on every page.
struct WindowBarSample: SampleContent, ExampleContent {
    // listing: WindowBarSample
    /// The values shared with the gallery window the sample is in.
    let bar: WindowBarState
    // listing: end

    static let id = "windowBar"
    static let title = "Window bar"
    static let summary = "Turn on an action every page carries."

    static var code: String { Listings.joined("WindowBarSample", "MainPage.bar") }

    var notes: (any View)? { nil }

    // listing: WindowBarSample
    var body: some View {
        Switch("Surprise me on every page", isOn: bar.$showsSurprise)
            .accessibilityIdentifier("windowBar.surprise")
    }
    // listing: end
}
