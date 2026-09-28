import StateUI

/// The other tab: a plain page, and the one that writes the selection.
///
/// A tab is nothing but a page in a list, so this one says its own caption
/// and its own picture through its session's `title` and `icon`.
/// Its button is `nav.tab = .stack`: the selection is a binding of the
/// gallery's own type, so moving the tabs from code is an assignment.
struct SecondTabPage: ContentView {
    /// The gallery this page is in - the scene its inspector button opens.
    @Environment var scene: SceneSession

    /// The page itself - what it is called, and its buttons.
    @Environment private var page: PageSession

    let nav: Navigation

    var content: any View {
        ScrollView {
            VStack {
                SectionTitle("The other tab")

                Label("Second")
                    .fontSize(26)
                    .fontAttributes(.bold)

                Button("Show the first tab")
                    .background(Palette.accent)
                    .textColor(.white)
                    .shape(.roundedRectangle(8))
                    .padding(20, 10)
                    .horizontalAlignment(.center)
                    .onClicked { nav.tab = .stack }

                TabsControls(nav: nav, thisTab: .second)

                Button("Back to the Navigation samples")
                    .padding(20, 10)
                    .horizontalAlignment(.center)
                    .onClicked { nav.openGroup("navigation") }
            }
            .spacing(14)
            .padding(24)
        }
        .onCreated {
            page.gallery("Second", scene: scene, nav: nav)
            page.icon = ImageSource(light: "tab_pages.png", dark: "tab_pages_dark.png")
        }
    }
}
