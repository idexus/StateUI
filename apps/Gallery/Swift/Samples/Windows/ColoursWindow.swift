import StateUI

/// The window a gallery chooses its accent in - a window OF THE GALLERY that
/// opened it, painting that gallery's bars and no other's. See
/// `MultiWindowSample`.
struct ColoursWindow: Window {
    var page: any Page { ColoursPage() }
}

/// The accents on offer, each drawn in itself.
struct ColoursPage: ContentPage {
    /// The gallery's look - the one its scene offers every window of it.
    @Environment private var style: SessionStyle

    /// The window this is the page of - what it is called, and how big.
    @Environment private var window: WindowSession

    /// The page itself - what it is called, and its padding.
    @Environment private var page: PageSession

    var content: any View {
        VStack {
            Label("The accent this gallery's bars are painted in.")
                .fontSize(13)
                .textColor(Palette.subtle)

            ForEach(AccentChoice.allCases) { accent in
                Button(style.accent == accent ? "✓  \(accent.name)" : accent.name)
                    .fontSize(15)
                    .textColor(.white)
                    .backgroundColor(accent.color)
                    .cornerRadius(8)
                    .padding(14, 8)
                    .onClicked { style.accent = accent }
            }

            // The window closes itself, through its own session.
            Button("Done")
                .fontSize(13)
                .padding(14, 6)
                .horizontalOptions(.end)
                .onClicked { try await window.close() }
        }
        .spacing(10)
        .onCreated {
            page.title = "Colours"
            page.padding = Thickness(16)

            window.title = "Colours"
            window.width = 320
            window.height = 340
            window.minimumWidth = 260
            window.minimumHeight = 240
        }
    }
}
