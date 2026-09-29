import StateUI

/// The first tab of the tabs demonstration - the one holding a stack of its own.
///
/// It is the ROOT of a `NavigationStack` that lives inside a `TabbedView`, and
/// that `TabbedView` is the detail of the same split view every other section
/// is shown in. All three are pages, and pages nest - so a tab may hold a
/// stack, and the stack it holds is its own array.
struct TabsPage: ContentView {
    /// The gallery this page is in - the scene its inspector button opens.
    @Environment var scene: SceneSession

    /// The page itself - what it is called, and its buttons.
    @Environment private var page: PageSession

    let nav: Navigation

    /// This TAB's own stack - a different array from the gallery's, which is
    /// the whole of why each tab keeps its place.
    @Binding var path: [Route]

    var content: any View {
        ScrollView {
            VStack {
                SectionTitle("A section arranged as tabs")

                Label("A TabbedView of two")
                    .fontSize(26)
                    .fontAttributes(.bold)

                Label("Push a page, change tabs, come back: it is still on top.")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                Button("Push a page onto this tab")
                    .background(Palette.accent)
                    .textColor(.white)
                    .shape(.roundedRectangle(8))
                    .padding(20, 10)
                    .horizontalAlignment(.center)
                    .onClicked { path.append(.level(1)) }

                Label("Depth here: \(path.count)")
                    .fontSize(13)
                    .fontFamily("Menlo")
                    .textColor(Palette.accent)
                    .horizontalTextAlignment(.center)

                TabsControls(nav: nav, thisTab: .stack)

                // One move, landing where it says: the section becomes home
                // and the group is pushed onto it, so the back button leads
                // home from there.
                Button("Back to the Navigation samples")
                    .padding(20, 10)
                    .horizontalAlignment(.center)
                    .onClicked { nav.openGroup("navigation") }
            }
            .spacing(14)
            .padding(24)
        }
        .onCreated { page.gallery("Tabs", scene: scene, nav: nav) }
    }
}
