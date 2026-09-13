// The gallery's simple group index.

import StateUI

/// Every sample group in catalog order, exposed through native buttons.
///
/// This is the gallery's dependable starting surface while native hosts gain
/// the controls needed by the richer gallery arrangement. It deliberately uses
/// only a scroller, stacks, labels, and buttons; the catalog and navigation
/// remain the same ones used by every other gallery page.
struct GroupListPage: ContentPage {
    /// The gallery this page is in - the scene its inspector button opens.
    @Environment var scene: SceneSession

    /// The page itself - what it is called, and its buttons.
    @Environment private var page: PageSession

    /// The sole list of groups shown by the application.
    let catalog: Catalog

    /// Where choosing a group pushes its page.
    let nav: Navigation

    var content: any View {
        ScrollView {
            VStack {
                Label("StateUI Gallery")
                    .style("Headline")

                Label("Choose a group of examples")
                    .style("SubHeadline")

                ForEach(catalog.groups, id: \.route) { group in
                    VStack {
                        Button(group.title)
                            .horizontalOptions(.fill)
                            .automationId("group.\(group.route)")
                            .semanticHint("Opens the \(group.title) examples")
                            .onClicked { nav.openGroup(group.route) }

                        Label(group.summary)
                            .fontSize(13)
                            .textColor(Palette.subtle)
                    }
                    .spacing(6)
                }
            }
            .spacing(16)
            .padding(24)
        }
        .onCreated { page.gallery("Home", scene: scene, nav: nil) }
    }
}
