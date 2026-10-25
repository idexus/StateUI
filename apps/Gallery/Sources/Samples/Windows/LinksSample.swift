import StateUI

/// Links into the application: the Gallery's own scheme, which the system hands back to it.
struct LinksSample: SampleContent, ExampleContent {
    // listing: LinksSample
    /// The links the application was asked to open - its scene's.
    let links: OpenedLinks
    // listing: end

    static let id = "links"
    static let title = "Links"
    static let summary = "A link of the application's own scheme opens it - and a window, where one can open."

    static var code: String { Listings.joined("LinksSample", "OpenedLinks", "GalleryScene") }

    var notes: (any View)? {
        Text("Open the link here, or from another application: the system hands it to the Gallery.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }

    // listing: LinksSample
    var body: some View {
        // Read here, so every link the scene hears builds this page again.
        let opened = links.addresses

        return VStack {
            DebugInfoLabel()

            Link("Open swatch 3", destination: GalleryLink.swatch(3))
                .horizontalAlignment(.center)
                .accessibilityIdentifier("links.swatch")

            SectionTitle("Opened")
            if opened.isEmpty {
                Text("No link yet.")
                    .fontSize(14)
                    .textColor(Palette.subtle)
            }
            ForEach(Array(opened.suffix(5).enumerated()), id: \.offset) { item in
                Text(item.element)
                    .fontSize(14)
            }
        }
        .spacing(10)
    }
    // listing: end
}
