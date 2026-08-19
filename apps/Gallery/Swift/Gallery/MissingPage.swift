// What a route asks for that the catalog does not have.

import StateUI

/// A sample route with no sample behind it.
///
/// Only reachable by pushing `.sample(id)` with an id nothing in the catalog
/// claims - a renamed sample, or a card that outlived its entry. Saying so is
/// better than a blank page, and better than throwing: the rest of the gallery
/// goes on working.
///
/// It is a rare page. In MAUI's Shell a route is a string looked up in a
/// registry, so a typo anywhere reaches a page nobody wrote; here the
/// `destination` closure is a `switch` over an enum and the compiler answers
/// for every case.
/// What is left is the id INSIDE the case, which is data - a catalog entry
/// renamed and a card not.
struct MissingPage: GalleryPage {
    let id: String

    let nav: Navigation

    /// The stack this page is on, so "Back" takes it off - the main one, or a
    /// tab's own.
    @Binding var path: [Route]

    var title: String? { "Not found" }

    var content: Element {
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
    }
}
