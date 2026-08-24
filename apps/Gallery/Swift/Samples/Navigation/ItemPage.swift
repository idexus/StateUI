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

    /// Whether the page says it is busy - a button below turns it on and off,
    /// which is the only way to see what each platform does with it.
    @State private var loading = false

    var title: String? { item.isEmpty ? "Item" : item }

    /// What a PAGE has that a view does not - both drawn by the platform,
    /// under everything this page describes. MAUI: Page.IsBusy and
    /// Page.BackgroundImageSource.
    ///
    /// `isBusy` puts the platform's own indicator wherever the platform puts
    /// one, which on some is nowhere at all; a page that wants a spinner in a
    /// place of its own puts an `ActivityIndicator` in its content instead.
    var isBusy: Bool? { loading }

    /// A backdrop, not a view: it takes no aspect and no placement, and sits
    /// under the whole page.
    var backgroundImageSource: ImageSource? { ImageSource("stateui_tile.png") }

    var content: Element {
        VStack {
            SectionTitle("PUSHED PAGE")

            Label(item.isEmpty ? "Nothing selected" : item)
                .fontSize(28)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            SwitchRow("Say the page is busy", $loading)
                .horizontalOptions(.center)

            Label("`isBusy` and `backgroundImageSource` belong to the PAGE, so they are "
                + "declared beside `title` rather than written on a view. The backdrop "
                + "under this page is the second of them.")
                .fontSize(12)
                .textColor(Palette.subtle)

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
