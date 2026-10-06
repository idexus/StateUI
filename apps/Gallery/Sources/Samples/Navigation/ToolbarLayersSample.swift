import StateUI

/// A page's actions coming and going with the page: a pushed page's own stand nearer the title, the gallery's keep
/// their place, and back the bar stands as it stood.
struct ToolbarLayersSample: SampleContent, ExampleContent {
    // listing: ToolbarLayersSample
    /// Where the gallery is: the button pushes a page onto its stack.
    let nav: Navigation

    /// How many times this page's own Refresh was pressed.
    @State private var refreshed = 0
    // listing: end

    static let id = "toolbarLayers"
    static let title = "Toolbar layers"
    static let summary = "A pushed page's own actions joining the bar, and leaving with the page."

    static var code: String { Listings.joined("ToolbarLayerPage", "ToolbarLayersSample") }

    // listing: ToolbarLayersSample
    var body: some View {
        VStack {
            DebugInfoLabel()

            Text("Refreshed \(refreshed) time(s)")
                .fontSize(17)

            Text("Open a page, look at the bar, then go back.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Button("Open a page with its own actions")
                .accessibilityIdentifier("layers.open")
                .padding(horizontal: 20, vertical: 10)
                .onClicked { nav.push(.layer(1)) }
        }
        .spacing(12)
        .toolbar {
            ToolbarItem("Refresh")
                .id("layers.refresh")
                .accessibilityIdentifier("layers.refresh")
                .onClicked { refreshed += 1 }
        }
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Every page declares its own actions where their state lives; the gallery "
                + "declares Inspector and Home once, around every page.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A pushed page's actions stand nearer the title and the gallery's keep their "
                + "place at the edge; going back takes the page's away, and nothing is restored "
                + "because nothing was overwritten.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
