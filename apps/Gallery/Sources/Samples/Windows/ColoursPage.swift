import StateUI

/// The colours on offer, each drawn in itself: the page of the window the
/// galleries choose their colour in, a window OF THEIR SCENE, for the bars
/// and the windows of every gallery window. See `MultiWindowSample`.
struct ColoursPage: View {
    /// The gallery's look - the one its scene offers every window of it.
    @Environment private var style: SessionStyle

    /// The window this is the page of - what it is called, and how big.
    @Environment(\.window) private var window

    var body: some View {
        VStack {
            Text("The colour this gallery wears.")
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

    /// The button choosing `accent`, drawn in it.
    private func choice(_ accent: AccentChoice) -> Button {
        let style = self.style
        return Button(style.barColour == accent ? "✓  \(accent.name)" : accent.name)
            .textColor(.white)
            .background(accent.color)
            .shape(.roundedRectangle(8))
            .onClicked {
                style.barColour = accent
                style.windowColour = accent
            }
    }
}
