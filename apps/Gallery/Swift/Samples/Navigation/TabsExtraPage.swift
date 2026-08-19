import StateUI

/// A tab the READER added - the reason the tab list is something that changes
/// rather than a fixed set.
///
/// Nothing distinguishes it from the two the demonstration opens with: a tab is
/// a page in a list, so a page built from a number is as much a tab as one
/// written out by hand.
struct TabsExtraPage: GalleryPage {
    /// Where the gallery is, and the moves that change the tab list.
    let nav: Navigation

    /// Which added tab this is. Its identity as well as its name - the tab is
    /// `DemoTab.extra(number)`, and that value is what the selection binding
    /// holds while this page is showing.
    let number: Int

    var title: String? { "Extra \(number)" }

    var iconImageSource: ImageSource? {
        ImageSource(light: "tab_pages.png", dark: "tab_pages_dark.png")
    }

    var content: Element {
        ScrollView {
            VStack {
                SectionTitle("A TAB THE READER ADDED")

                Label("Extra \(number)")
                    .fontSize(26)
                    .fontAttributes(.bold)

                Label("`DemoTab.extra(\(number))` is an ordinary value in an ordinary "
                    + "array, and the page you are reading is what the TabbedPage's "
                    + "closure answered for it. Adding a tab is `tabs.append`; there is "
                    + "no tab type, no template and nothing to register.")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                TabsControls(nav: nav, thisTab: .extra(number))

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
