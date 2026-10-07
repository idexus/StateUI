import StateUI

/// The accents on offer, each drawn in itself: the page of the window the
/// galleries choose their accent in, a window OF THEIR SCENE, painting the
/// bars of every gallery window. See `MultiWindowSample`.
struct ColoursPage: View {
    /// The gallery's look - the one its scene offers every window of it.
    @Environment private var style: SessionStyle

    /// The window this is the page of - what it is called, and how big.
    @Environment(\.window) private var window

    var body: some View {
        VStack {
            Text("The accent this gallery's bars are painted in.")
                .textColor(Palette.subtle)

            ForEach(AccentChoice.allCases) { accent in
                choice(accent)
            }

            // The window closes itself, through its own session.
            Button("Done")
                .horizontalAlignment(.end)
                .onClicked { try await window.close() }
        }
        .spacing(10)
        .padding(16)
        .title("Colours")
        .onCreated {
            window.title = "Colours"
            window.width = 320
            window.height = 380
            window.minimumWidth = 260
            window.minimumHeight = 240
        }
    }

    /// The button choosing `accent`, drawn in it where it is a colour.
    private func choice(_ accent: AccentChoice) -> Button {
        let style = self.style
        let button = Button(style.accent == accent ? "✓  \(accent.name)" : accent.name)
            .onClicked { style.accent = accent }
        guard let colour = accent.color else { return button }
        return button.textColor(.white).background(colour).shape(.roundedRectangle(8))
    }
}
