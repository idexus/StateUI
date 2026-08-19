import StateUI

/// The other tab: a plain page, and the one that writes the selection.
///
/// A tab is nothing but a page in a list, so this one carries its own caption
/// and its own picture - `title` and `iconImageSource`, MAUI's own page
/// properties, which is where a TabbedPage reads them from.
struct SecondTabPage: GalleryPage {
    let nav: Navigation

    var title: String? { "Second" }

    var iconImageSource: ImageSource? {
        ImageSource(light: "tab_pages.png", dark: "tab_pages_dark.png")
    }

    var content: Element {
        ScrollView {
            VStack {
                SectionTitle("THE OTHER TAB")

                Label("Second")
                    .fontSize(26)
                    .fontAttributes(.bold)

                Label("A tab is a page in a list, so this page says what its tab is "
                    + "called and what its picture is - `title` and `iconImageSource`, "
                    + "which are MAUI's own page properties. The tab beside it is a whole "
                    + "NavigationPage, so the stack says those instead of the page inside "
                    + "it: a tab's caption belongs to whatever the tab HOLDS.")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                Button("Show the first tab")
                    .backgroundColor(Palette.accent)
                    .textColor(.white)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .horizontalOptions(.center)
                    .onClicked { nav.tab = .stack }

                Label("`nav.tab = .stack` - the selection is a binding of the author's own "
                    + "type, so moving the tabs from code is an assignment, and a reader "
                    + "tapping a tab (or, on Android, SWIPING between them) writes the "
                    + "same binding back.")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                TabsControls(nav: nav, thisTab: .second)

                Button("Back to the Navigation samples")
                    .padding(20, 10)
                    .horizontalOptions(.center)
                    .onClicked { nav.openGroup("navigation") }
            }
            .spacing(14)
            .padding(24)
        }
    }
}
