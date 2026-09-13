import StateUI

/// A window FOR A VALUE: one per swatch number, the number lent to the window
/// as its own - so writing it makes the same window about another swatch, and
/// the system restores the window for the number it was left on. See
/// `MultiWindowSample`.
struct SwatchWindow: Window {
    /// Which swatch the window is for - its value, lent by its group.
    @Binding var number: Int

    var page: any Page { SwatchPage(number: $number) }
}

/// One swatch: its colour, its number, and a way on to the next.
struct SwatchPage: ContentPage {
    /// The window's own value.
    @Binding var number: Int

    /// The window this is the page of - named for its swatch, and closed from
    /// here.
    @Environment private var window: WindowSession

    /// The page itself - its padding.
    @Environment private var page: PageSession

    var content: any View {
        VStack {
            BoxView()
                .color(SwatchPage.colour(of: number))
                .heightRequest(150)
                .cornerRadius(12)

            Label("Swatch \(number)")
                .fontSize(20)
                .fontAttributes(.bold)
                .horizontalOptions(.center)

            HStack {
                Button("Next")
                    .fontSize(13)
                    .padding(14, 6)
                    .onClicked { number += 1 }

                Button("Done")
                    .fontSize(13)
                    .padding(14, 6)
                    .onClicked { try await window.close() }
            }
            .spacing(10)
            .horizontalOptions(.center)
        }
        .spacing(14)
        .onCreated {
            page.padding = Thickness(16)

            window.title = "Swatch \(number)"
            window.width = 300
            window.height = 340
            window.minimumWidth = 240
            window.minimumHeight = 280
        }
        // The same window, now about another swatch - so its name follows.
        .onChanged(number) { window.title = "Swatch \(number)" }
    }

    /// The colour of a swatch - the gallery's accents, in turn.
    static func colour(of number: Int) -> Color {
        let accents = AccentChoice.allCases
        let index = ((number - 1) % accents.count + accents.count) % accents.count
        return accents[index].color
    }
}
