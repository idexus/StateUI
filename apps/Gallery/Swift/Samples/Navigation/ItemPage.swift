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

    /// What a PAGE has that a view does not: drawn by the platform, under
    /// everything this page describes. MAUI: Page.BackgroundImageSource.
    ///
    /// A backdrop, not a view: it takes no aspect and no placement, and sits
    /// under the whole page.
    var backgroundImageSource: ImageSource? { ImageSource("stateui_tile.png") }

    var content: Element {
        // ON A PANEL, because the backdrop is a picture and words over a
        // picture cannot be read - which is the trap this page exists to show
        // rather than fall into. The tile stands around the panel, where it
        // says plainly that it is under everything.
        Border {
            VStack {
                SectionTitle("PUSHED PAGE")

                Label(item.isEmpty ? "Nothing selected" : item)
                    .fontSize(28)
                    .fontAttributes(.bold)
                    .horizontalTextAlignment(.center)

                Label("`backgroundImageSource` belongs to the PAGE, so it is declared "
                    + "beside `title` rather than written on a view. The picture around "
                    + "this panel is it: a backdrop, which takes no aspect and no "
                    + "placement, where an `Image` in the content would be a view that "
                    + "can be sized and placed.")
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
        }
        .padding(24)
        .margin(24)
        .backgroundColor(Palette.surface)
        .stroke(.transparent)
        .strokeShape(.roundRectangle(12))
        .verticalOptions(.center)
    }
}
