import StateUI

/// The families on offer, each set in itself: the page of the window the
/// galleries choose their font in, a window OF THEIR SCENE. It closes with
/// that scene, may step aside for another, and changes what every gallery
/// window shows. See `MultiWindowSample`.
struct FontsPage: View {
    /// The gallery's look - the one its scene offers every window of it.
    @Environment private var style: SessionStyle

    /// The window this is the page of - what it is called, and how big.
    @Environment(\.window) private var window

    /// Families every desktop this gallery runs on has; empty is the
    /// platform's own.
    static let families = ["", "Georgia", "Courier New", "Trebuchet MS"]

    var body: some View {
        VStack {
            Text("The font this gallery's preview is set in.")
                .textColor(Palette.subtle)

            ForEach(FontsPage.families) { family in
                let name = family.isEmpty ? "The platform's own" : family
                let button = Button(style.font == family ? "✓  \(name)" : name)
                    .onClicked { style.font = family }

                return family.isEmpty ? button : button.fontFamily(family)
            }

            // The window closes itself, through its own session.
            Button("Done")
                .horizontalAlignment(.end)
                .onClicked(gate: .ignoreWhileRunning) { try await window.close() }
        }
        .spacing(10)
        .padding(16)
        .title("Fonts")
        .onCreated {
            window.title = "Fonts"
            window.width = 320
            window.height = 380
            window.minimumWidth = 260
            window.minimumHeight = 260
        }
    }
}
