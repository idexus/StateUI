import StateUI

/// A page pushed for one thing chosen from the search box.
///
/// What it shows arrives as a VALUE of the route - `.item("Alpha")` - not as
/// global state and not as a dictionary of strings, which is what lets two of
/// these be on the stack at once showing different things.
struct ItemPage: GalleryPage {
    let item: String

    let nav: Navigation

    /// The stack this page is on, so "Back" takes it off.
    @Binding var path: [Route]

    var title: String? { item.isEmpty ? "Item" : item }

    var content: Element {
        VStack {
            SectionTitle("PUSHED PAGE")

            Label(item.isEmpty ? "Nothing selected" : item)
                .fontSize(28)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label("Pushed by `path.append(.item(\"\(item)\"))`. The parameter is a field of "
                + "the enum, so it never has to cross the boundary at all - the host is "
                + "sent the page this side built from it, and knows nothing about routes "
                + "or their arguments.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Button("Back")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { path.removeLast() }
        }
        .spacing(16)
        .padding(24)
    }
}
