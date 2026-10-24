import StateUI

/// A fill: the room it is offered, made of a material in its shape - or clear, for the hand; beside it, a space.
struct FillSample: SampleContent, ExampleContent {
    // listing: FillSample
    /// Whether the room between the words is a space rather than a fill.
    @State private var spaced = false

    /// How many taps the clear fill heard.
    @State private var taps = 0
    // listing: end

    static let id = "fill"
    static let title = "Fill and space"
    static let summary = "Room made of a color, a gradient, a blur or glass: the room offered, or the room left."

    // listing: FillSample
    var body: some View {
        VStack {
            SectionTitle("Offered or left")

            // Along a stack a fill is as long as it says - nothing here; a space pushes, taking the rest.
            VStack {
                Text("Top")
                if spaced {
                    Space()
                        .background(Palette.accent)
                        .shape(.roundedRectangle(10))
                } else {
                    Fill(Palette.accent)
                        .shape(.roundedRectangle(10))
                }
                Text("Bottom")
            }
            .spacing(8)
            .height(160)

            Switch($spaced)
                .text("A space, not a fill")
                .accessibilityIdentifier("fill.spaced")

            SectionTitle("Across")

            // As wide as it says, as tall as its row offers.
            HStack {
                Fill(Palette.accent)
                    .width(4)
                Text("Take the room you are given.")
                    .fontAttributes(.italic)
                    .padding(horizontal: 0, vertical: 8)
            }
            .spacing(10)

            SectionTitle("Made of")

            // Each over a stripe of color, so what it lets through shows.
            Grid {
                tile("Color", Fill(Palette.accent), over: .tomato).gridColumn(0)
                tile("Gradient", Fill(Palette.identity), over: .gold).gridColumn(1)
                tile("Blur", Fill(.blur(.regular)), over: .steelBlue).gridColumn(2)
                tile("Glass", Fill(.glass(.regular)), over: .white).gridColumn(3)
            }
            .columns(.fill, .fill, .fill, .fill)
            .height(110)
            .shape(.roundedRectangle(14))
            .clipsContent(true)

            SectionTitle("For the hand")

            // Clear, only outlined, it still hears a tap anywhere on it.
            ZStack {
                Text(taps == 0 ? "Tap anywhere here" : taps == 1 ? "Tapped once" : "Tapped \(taps) times")
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
                Fill()
                    .shape(.roundedRectangle(14))
                    .stroke(Palette.outline)
                    .lineWidth(1)
                    .onTapped { taps += 1 }
                    .accessibilityIdentifier("fill.hand")
            }
            .height(80)
        }
        .spacing(12)
    }

    /// A rounded fill with its name in its middle, standing alike on every side in a stripe of `stripe`.
    private func tile(_ name: String, _ fill: Fill, over stripe: Color) -> ZStack {
        ZStack {
            Fill(stripe)
            fill
                .shape(.roundedRectangle(10))
                .margin(12)
            Text(name)
                .fontSize(12)
                .fontWeight(.bold)
                .horizontalAlignment(.center)
                .verticalAlignment(.center)
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("A `Fill` is made of what it is given - a color, a gradient, a blur or glass - in its box's "
            + "shape, outlined where it says so, and takes the room it is offered. A `Space` pushes: in a "
            + "stack it takes the room the others leave, and it may be drawn alike.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
