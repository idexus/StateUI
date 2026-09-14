import StateUI

/// The page the menu does not always list - see `MenuPage`, where the row is
/// written inside an `if`.
///
/// The list is a view and the destination is a value: `.hidden` is a case of
/// an enum, so a row for it is optional in the plainest sense of the word -
/// written inside an `if`, while the page behind it stays reachable from
/// anywhere that can name the case.
struct HiddenPage: ContentView {
    /// The gallery this page is in - the scene its inspector button opens.
    @Environment var scene: SceneSession

    /// The page itself - what it is called, and its buttons.
    @Environment private var page: PageSession

    let nav: Navigation

    var content: any View {
        ScrollView {
            VStack {
                SectionTitle("A row that is not there")

                Label("Not in the list")
                    .fontSize(26)
                    .fontAttributes(.bold)

                Label("The menu lists this page only when the Split view sample's "
                    + "switch says so.")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                Button("Back to the Navigation samples")
                    .backgroundColor(Palette.accent)
                    .textColor(.white)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .horizontalAlignment(.center)
                    .onClicked { nav.openGroup("navigation") }
            }
            .spacing(14)
            .padding(24)
        }
        .onCreated { page.gallery("Not in the list", scene: scene, nav: nav) }
    }
}
