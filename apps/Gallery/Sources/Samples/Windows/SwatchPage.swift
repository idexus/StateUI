import StateUI

/// One swatch - its color, its number, and a way on to the next: the page of a
/// window FOR A VALUE, one per swatch number. The number is lent to the window
/// as its own, so writing it makes the same window about another swatch, and
/// the system restores the window for the number it was left on. See
/// `MultiWindowSample`.
struct SwatchPage: View {
    /// Which swatch the window is for - its value, lent by its group.
    @Binding.Proxy var number: Int

    /// The window this is the page of - named for its swatch, and closed from
    /// here.
    @Environment(\.window) private var window

    var body: some View {
        VStack {
            Rectangle()
                .fill(SwatchPage.color(of: number))
                .height(150)
                .cornerRadius(12)

            Text("Swatch \(number)")
                .fontSize(20)
                .fontWeight(.bold)
                .horizontalAlignment(.center)

            HStack {
                Button("Next")
                    .onClicked { number += 1 }

                Button("Done")
                    .onClicked(.ignoreWhileRunning) { try await window.close() }
            }
            .spacing(10)
            .horizontalAlignment(.center)
        }
        .spacing(14)
        .padding(16)
        .onCreated {
            window.title = "Swatch \(number)"
            window.width = 300
            window.height = 340
            window.minimumWidth = 240
            window.minimumHeight = 280
        }
        // A written number makes the same window about another swatch, so its
        // name follows.
        .onChanged(number) { window.title = "Swatch \(number)" }
    }

    /// The color of a swatch - the gallery's painted accents, in turn.
    static func color(of number: Int) -> Color {
        let colors = AccentChoice.own.map { $0.color(system: .gray, for: .bar) }
        let index = ((number - 1) % colors.count + colors.count) % colors.count
        return colors[index]
    }
}
