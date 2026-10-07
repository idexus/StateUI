import StateUI

/// The other tab: a plain page, and the one that writes the selection.
///
/// A tab is nothing but a page in a list, so this one says its own caption
/// and its own picture by modifier, `title` and `icon`.
/// Its button is `nav.tab = .stack`: the selection is a binding of the
/// gallery's own type, so moving the tabs from code is an assignment.
struct SecondTabPage: View {
    /// The gallery this page is in - its scene.
    @Environment(\.scene) var scene

    let nav: Navigation

    var body: some View {
        ScrollView {
            VStack {
                SectionTitle("The other tab")

                Text("Second")
                    .fontSize(26)
                    .fontAttributes(.bold)

                Button("Show the first tab")
                    .horizontalAlignment(.center)
                    .onClicked { nav.tab = .stack }

                TabsControls(nav: nav, thisTab: .second)

                Button("Back to the Navigation samples")
                    .horizontalAlignment(.center)
                    .onClicked { nav.openGroup("navigation") }
            }
            .spacing(14)
            .padding(24)
        }
        .galleryPage("Second")
        .icon(ImageSource(light: "tab_pages.png", dark: "tab_pages_dark.png"))
    }
}
