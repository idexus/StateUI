import StateUI

/// The window a gallery chooses its font in - a window OF THE GALLERY that
/// opened it: it closes with that gallery, may step aside for another, and
/// changes what this gallery shows and no other. See `MultiWindowSample`.
struct FontsWindow: Window {
    var page: any Page { FontsPage() }
}

/// The families on offer, each set in itself.
struct FontsPage: ContentPage {
    /// The gallery's look - the one its scene offers every window of it.
    @Environment private var style: SessionStyle

    /// The window this is the page of - what it is called, and how big.
    @Environment private var window: WindowSession

    /// The page itself - what it is called, and its padding.
    @Environment private var page: PageSession

    /// Families every desktop this gallery runs on has; empty is the
    /// platform's own.
    static let families = ["", "Georgia", "Courier New", "Trebuchet MS"]

    var content: any View {
        VStack {
            Label("The font this gallery's preview is set in.")
                .fontSize(13)
                .textColor(Palette.subtle)

            ForEach(FontsPage.families) { family -> Element in
                let chosen = style.font == family
                let button = Button(family.isEmpty ? "The platform's own" : family)
                    .fontSize(15)
                    .textColor(chosen ? .white : Palette.text)
                    .backgroundColor(chosen ? style.accent.color : .transparent)
                    .borderColor(Palette.subtle)
                    .borderWidth(chosen ? 0 : 1)
                    .cornerRadius(8)
                    .padding(14, 8)
                    .onClicked { style.font = family }

                return family.isEmpty ? button : button.fontFamily(family)
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
            page.title = "Fonts"
            page.padding = Thickness(16)

            window.title = "Fonts"
            window.width = 320
            window.height = 380
            window.minimumWidth = 260
            window.minimumHeight = 260
        }
    }
}
