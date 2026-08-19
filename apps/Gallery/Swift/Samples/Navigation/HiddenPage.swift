import StateUI

/// The page the menu does not always list - see `MenuPage`, where the row is
/// written inside an `if`.
///
/// What it demonstrates is how little there is left to demonstrate. A Shell had
/// `flyoutItemIsVisible` on an item the library held, and the page behind it was
/// reachable by a route the list did not show. Here the list is a view and the
/// destination is a value: `.hidden` is a case of an enum, so a row for it is
/// optional in the plainest sense of the word.
struct HiddenPage: GalleryPage {
    let nav: Navigation

    var title: String? { "Not in the list" }

    var content: Element {
        ScrollView {
            VStack {
                SectionTitle("A ROW THAT IS NOT THERE")

                Label("Not in the list")
                    .fontSize(26)
                    .fontAttributes(.bold)

                Label("This is an ordinary section - `nav.open(.hidden)` reaches it like "
                    + "any other. What the menu does is draw a row for it only when the "
                    + "Flyout sample's switch says so, and a list that is a view needs "
                    + "nothing more than an `if` to say that.")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                Label("The bar above is the NavigationPage's, like every other bar in this "
                    + "app. A Shell let an ITEM paint the bar for every page under it, "
                    + "with MAUI resolving whichever element was deepest; a stack's bar "
                    + "belongs to the stack, and what a page may still ask of it is "
                    + "whether it is there at all - `navigationPageHasNavigationBar`.")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                Button("Back to the Navigation samples")
                    .backgroundColor(Palette.accent)
                    .textColor(.white)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .horizontalOptions(.center)
                    .onClicked { nav.openGroup("navigation") }
            }
            .spacing(14)
            .padding(24)
        }
    }
}
