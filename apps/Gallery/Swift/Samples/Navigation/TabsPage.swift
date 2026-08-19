import StateUI

/// The first tab of the tabs demonstration - the one holding a stack of its own.
///
/// It is the ROOT of a `NavigationPage` that lives inside a `TabbedPage`, which
/// is a composition a Shell forbade: a Tab was shell STRUCTURE, so the pages
/// under one could only be declared beside the flyout items. Here every one of
/// the three is a page, and pages nest.
struct TabsPage: GalleryPage {
    let nav: Navigation

    /// This TAB's own stack - a different array from the gallery's, which is
    /// the whole of why each tab keeps its place.
    @Binding var path: [Route]

    var title: String? { "Tabs" }

    var content: Element {
        ScrollView {
            VStack {
                SectionTitle("A SECTION ARRANGED AS TABS")

                Label("A TabbedPage of two")
                    .fontSize(26)
                    .fontAttributes(.bold)

                Label("The row of tabs is a TabbedPage, and it is the DETAIL of the same "
                    + "flyout every other section is shown in. Nothing about this page "
                    + "says so: what arranges it is which section the menu chose.")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                Label("This tab holds a NavigationPage over a path of its own. Push a page, "
                    + "change tabs, come back - it is still on top, because the two stacks "
                    + "are two arrays and nothing in the library decides that.")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                Button("Push a page onto this tab")
                    .backgroundColor(Palette.accent)
                    .textColor(.white)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .horizontalOptions(.center)
                    .onClicked { path.append(.level(1)) }

                Label("Depth here: \(path.count)")
                    .fontSize(13)
                    .fontFamily("Menlo")
                    .textColor(Palette.accent)
                    .horizontalTextAlignment(.center)

                TabsControls(nav: nav, thisTab: .stack)

                Button("Back to the Navigation samples")
                    .padding(20, 10)
                    .horizontalOptions(.center)
                    .onClicked { nav.openGroup("navigation") }

                Label("The way out is one assignment, and it lands where it says: the "
                    + "section becomes the group, and the group's page is what the detail "
                    + "shows. There is no route syntax to get wrong - which is what this "
                    + "button was written twice to work around before.")
                    .fontSize(13)
                    .textColor(Palette.subtle)
            }
            .spacing(14)
            .padding(24)
        }
    }
}
