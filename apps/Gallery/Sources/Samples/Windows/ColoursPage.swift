import StateUI

/// The colours on offer, each drawn in itself: the page of the window the
/// galleries choose their colour in, a window OF THEIR SCENE, for the bars
/// and the windows of every gallery window. See `MultiWindowSample`.
struct ColoursPage: View {
    /// The gallery's look - the one its scene offers every window of it.
    @Environment private var style: SessionStyle

    /// The window this is the page of - what it is called, and how big.
    @Environment(\.window) private var window

    /// The application - the accent the user chose for the system.
    @Environment(\.application) private var application

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

    /// The button choosing `accent` for the bars, the window and the sidebar
    /// in both themes, drawn in it - marked where the theme in force wears it.
    private func choice(_ accent: AccentChoice) -> Button {
        let style = self.style
        let worn = style.look(dark: application.info.colorScheme == .dark).barColour
        return Button(worn == accent ? "✓  \(accent.name)" : accent.name)
            .textColor(accent.carriesThemesWords ? Palette.text : .white)
            .background(accent.color(system: application.info.accentColor, for: .bar))
            .shape(.roundedRectangle(8))
            .onClicked {
                for look in [\SessionStyle.lightLook, \.darkLook] {
                    style[keyPath: look].barColour = accent
                    style[keyPath: look].window.colour = accent
                    style[keyPath: look].sidebar.colour = accent
                    style[keyPath: look].flyout.colour = accent
                }
            }
    }
}
