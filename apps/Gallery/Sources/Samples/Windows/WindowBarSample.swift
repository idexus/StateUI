import StateUI

// listing: WindowBarSample
/// What the gallery's window says on its bar, written by the sample and declared by the window.
@MainActor
final class WindowBarState {
    /// The line under the bar's title.
    @State var subtitle = ""

    /// Whether the window's bar carries "Surprise me" on every page.
    @State var showsSurprise = false
}
// listing: end

/// The bar the window declares on its page: the application's name, a line under the title, and an action on every
/// page.
struct WindowBarSample: SampleContent, ExampleContent {
    // listing: WindowBarSample
    /// The values shared with the gallery window the sample is in.
    let bar: WindowBarState
    // listing: end

    static let id = "windowBar"
    static let title = "Window bar"
    static let summary = "Type a line for the bar, then turn on an action every page carries."

    static var code: String { Listings.joined("WindowBarSample", "MainPage.bar") }

    var notes: (any View)? { nil }

    // listing: WindowBarSample
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
    // listing: end
}
