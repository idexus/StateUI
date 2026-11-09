import StateUI

// listing: WindowBarSample
/// What the gallery's window says on its bar, written by the sample and declared by the window and the sample's page.
@MainActor
final class WindowBarState {
    /// The line under the sample page's title.
    @State var subtitle = ""

    /// Whether the window's bar carries "Surprise me" on every page.
    @State var showsSurprise = false
}
// listing: end

/// The bar: the line a page says under its title, and an action the window declares on every page.
struct WindowBarSample: SampleContent, ExampleContent {
    // listing: WindowBarSample
    /// The values shared with the gallery window the sample is in.
    let bar: WindowBarState
    // listing: end

    static let id = "windowBar"
    static let title = "Window bar"
    static let summary = "Type a line under this page's title, then turn on an action every page carries."

    static var code: String { Listings.joined("WindowBarSample", "SamplePage.subtitle", "MainPage.bar") }

    var notes: (any View)? { nil }

    // listing: WindowBarSample
    /// The line under this page's title, wherever its title shows: the
    /// sample's page says it (`SamplePage.subtitle`).
    var subtitle: Binding<String>? { bar.$subtitle }

    var body: some View {
        VStack {
            TextField(bar.$subtitle)
                .accessibilityIdentifier("windowBar.subtitle")
                .accessibilityLabel("Subtitle for the window")
                .placeholder("Window subtitle")

            Switch("Surprise me on every page", isOn: bar.$showsSurprise)
                .accessibilityIdentifier("windowBar.surprise")
        }
        .spacing(12)
    }
    // listing: end
}
