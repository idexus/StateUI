import StateUI

/// A page the toolbar's layers push: its own actions on the bar while it is shown, and a way one page deeper.
///
/// Its actions stand nearer the title than the gallery's, which keep their place at the edge; going back takes them
/// away with the page, and the bar stands as it stood before the push.
struct ToolbarLayerPage: View {
    /// The page itself - what it is called.
    @Environment private var page: PageSession

    /// How deep it stands, from 1.
    let depth: Int

    /// The stack this page is on, which "Deeper" pushes onto.
    @Binding var path: [Route]

    /// How many times this page's Share was pressed.
    @State private var shared = 0

    var body: some View {
        VStack {
            Text("Layer \(depth)")
                .fontSize(28)
                .fontAttributes(.bold)

            Text("Shared \(shared) time(s)")
                .fontSize(14)
                .textColor(Palette.subtle)

            Text("Go back and this page's actions leave with it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
        .padding(24)
        .toolbar {
            ToolbarItem("Share")
                .id("layer.share")
                .accessibilityIdentifier("layer.share")
                .onClicked { shared += 1 }

            ToolbarItem("Deeper")
                .id("layer.deeper")
                .accessibilityIdentifier("layer.deeper")
                .onClicked { path.append(.layer(depth + 1)) }
        }
        .onCreated { page.gallery("Layer \(depth)") }
    }
}
