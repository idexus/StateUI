import StateUI

/// A tab the USER added - the reason the tab list is something that changes
/// rather than a fixed set.
///
/// Nothing distinguishes it from the two the demonstration opens with: a tab is
/// a page in a list, so a page built from a number is as much a tab as one
/// written out by hand. Adding one is `tabs.append`, and this page is what the
/// `TabView`'s closure answers for the value.
struct TabsExtraPage: View {
    /// The gallery this page is in - the scene its inspector button opens.
    @Environment(\.scene) var scene

    /// Where the gallery is, and the moves that change the tab list.
    let nav: Navigation

    /// Which added tab this is. Its identity as well as its name - the tab is
    /// `DemoTab.extra(number)`, and that value is what the selection binding
    /// holds while this page is showing.
    let number: Int

    var body: some View {
        ScrollView {
            VStack {
                SectionTitle("A tab the user added")

                Text("Extra \(number)")
                    .fontSize(26)
                    .fontAttributes(.bold)

                Text("This tab is `.extra(\(number))`, one value in the tabs array.")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                TabsControls(nav: nav, thisTab: .extra(number))

                Button("Back to the Navigation samples")
                    .padding(horizontal: 20, vertical: 10)
                    .horizontalAlignment(.center)
                    .onClicked { nav.openGroup("navigation") }
            }
            .spacing(14)
            .padding(24)
        }
        .galleryPage("Extra \(number)")
        .icon(ImageSource(light: "tab_pages.png", dark: "tab_pages_dark.png"))
    }
}
