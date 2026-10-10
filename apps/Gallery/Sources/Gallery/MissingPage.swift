// What a route asks for that the catalog does not have.

import StateUI

/// A sample or group route with nothing behind it.
///
/// Only reachable by pushing `.sample(id)` or `.group(id)` with an id nothing
/// in the catalog claims - a renamed sample, or a card that outlived its entry. Saying so is
/// better than a blank page, and better than throwing: the rest of the gallery
/// goes on working.
///
/// It is a rare page, because the `destination` closure is a `switch` over an
/// enum and the compiler answers for every case - there is no route string to
/// mistype. What is left is the id INSIDE the case, which is data: a catalog
/// entry renamed and a card not.
struct MissingPage: View {
    /// The gallery this page is in - its scene.
    @Environment(\.scene) var scene

    let id: String

    let nav: Navigation

    /// The stack this page is on, so "Back" takes it off - the main one, or a
    /// tab's own.
    @Binding var path: [Route]

    var body: some View {
        VStack {
            Text("Nothing called \"\(id)\"")
                .fontSize(20)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Text("The route asked for a page the catalog does not have.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Button("Back")
                .horizontalAlignment(.center)
                .onClicked { path.removeLast() }
        }
        .spacing(16)
        .padding(24)
        .galleryPage("Not found")
    }
}
