import StateUI

/// Links into the application: the Gallery's own scheme, which the system hands back to the window it opens in.
struct LinksSample: SampleContent, ExampleContent {
    // listing: LinksSample
    /// Where this window is, and the links it was given.
    let nav: Navigation
    // listing: end

    static let id = "links"
    static let title = "Links"
    static let summary = "A link of the application's own scheme opens it - and the page it names, in its window."

    static var code: String { Listings.joined("LinksSample", "MainPage.links", "GalleryLink") }

    var notes: (any View)? {
        Text("Open the link here, or from another application: the system hands it to the Gallery.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }

    // listing: LinksSample
    var body: some View {
        // Read here, so every link this window is given builds this page again.
        let given = nav.links

        return VStack {
            DebugInfoLabel()

            Link("Open the Tap sample", destination: GalleryLink.sample("tap"))
                .horizontalAlignment(.center)
                .accessibilityIdentifier("links.tap")

            SectionTitle("Given to this window")
            if given.isEmpty {
                Text("No link yet.")
                    .fontSize(14)
                    .textColor(Palette.subtle)
            }
            ForEach(Array(given.suffix(5).enumerated()), id: \.offset) { item in
                Text(item.element)
                    .fontSize(14)
            }
        }
        .spacing(10)
    }
    // listing: end
}
