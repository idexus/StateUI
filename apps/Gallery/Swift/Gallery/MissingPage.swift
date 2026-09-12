// What a route asks for that the catalog does not have.

import StateUI

/// A sample route with no sample behind it.
///
/// Only reachable by pushing `.sample(id)` with an id nothing in the catalog
/// claims - a renamed sample, or a card that outlived its entry. Saying so is
/// better than a blank page, and better than throwing: the rest of the gallery
/// goes on working.
///
/// It is a rare page, because the `destination` closure is a `switch` over an
/// enum and the compiler answers for every case - there is no route string to
/// mistype. What is left is the id INSIDE the case, which is data: a catalog
/// entry renamed and a card not.
struct MissingPage: ContentPage {
    /// The gallery this page is in - the scene its inspector button opens.
    @Environment var scene: SceneSession

    /// The page itself - what it is called, and its buttons.
    @Environment private var page: PageSession

    let id: String

    let nav: Navigation

    /// The stack this page is on, so "Back" takes it off - the main one, or a
    /// tab's own.
    @Binding var path: [Route]

    var content: any View {
        VStack {
            Label("No sample called \"\(id)\"")
                .fontSize(20)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label("The route asked for a sample the catalog does not have. Every sample "
                + "is named in Gallery/Catalog.swift; this id is not one of them.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Button("Back")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { path.removeLast() }
        }
        .spacing(16)
        .padding(24)
        .onCreated { page.gallery("Not found", scene: scene, nav: nav) }
    }
}
