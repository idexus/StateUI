import StateUI

/// A page pushed for one thing chosen from the search box.
///
/// What it shows arrives as a VALUE of the route - `.item("Alpha")` - which is
/// what lets two of these be on the stack at once showing different things.
/// The value never crosses to the host: the host is sent the page built from
/// it, and knows nothing about routes or their arguments.
struct ItemPage: View {
    /// The gallery this page is in - the scene its inspector button opens.
    @Environment(\.scene) var scene

    let item: String

    let nav: Navigation

    /// The stack this page is on, so "Back" takes it off.
    @Binding var path: [Route]

    var body: some View {
        ZStack {
            VStack {
                SectionTitle("Pushed page")

                Text(item.isEmpty ? "Nothing selected" : item)
                    .fontSize(28)
                    .fontAttributes(.bold)
                    .horizontalTextAlignment(.center)

                Text("Pushed by `path.append(.item(\"\(item)\"))`.")
                    .fontSize(13)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)

                Button("Back")
                    .padding(horizontal: 20, vertical: 10)
                    .horizontalAlignment(.center)
                    .onClicked { path.removeLast() }
            }
            .spacing(16)
        }
        .style("Card")
        .padding(24)
        .margin(24)
        .background(Palette.surface)
        .stroke(.transparent)
        .shape(.roundedRectangle(12))
        .verticalAlignment(.center)
        .galleryPage(item.isEmpty ? "Item" : item)
    }
}
