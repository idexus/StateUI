import StateUI

/// A filler: a region that takes the room it is given, made of a material in its shape - or clear, for the hand.
struct FillerSample: SampleContent, ExampleContent {
    // listing: FillerSample
    /// Whether a spacer stands beside the filler, sharing the room left.
    @State private var shared = false

    /// How many taps the clear filler heard.
    @State private var taps = 0
    // listing: end

    static let id = "filler"
    static let title = "Filler"
    static let summary = "A region that takes the room it is given, made of a color, a gradient, a blur or glass."

    // listing: FillerSample
    var body: some View {
        VStack {
            SectionTitle("The room left")

            // The filler takes what the words leave; a spacer beside it shares that alike.
            VStack {
                Text("Top")
                Filler(Palette.accent)
                if shared { Spacer() }
                Text("Bottom")
            }
            .spacing(8)
            .height(160)

            Switch($shared)
                .text("Spacer beside it")
                .accessibilityIdentifier("filler.shared")

            SectionTitle("Across")

            // As wide as it says, as tall as its row.
            HStack {
                Filler(Palette.accent)
                    .width(4)
                Text("Take the room you are given.")
                    .fontAttributes(.italic)
                    .padding(horizontal: 0, vertical: 8)
            }
            .spacing(10)

            SectionTitle("Made of")

            ZStack {
                // Stripes, each filler an equal share of its row.
                HStack {
                    Filler(.tomato)
                    Filler(.gold)
                    Filler(.steelBlue)
                    Filler(.white)
                }

                Grid {
                    tile("Color", Filler(Palette.accent)).gridColumn(0)
                    tile("Gradient", Filler(Palette.identity)).gridColumn(1)
                    tile("Blur", Filler(.blur(.regular))).gridColumn(2)
                    tile("Glass", Filler(.glass(.regular))).gridColumn(3)
                }
                .columns(.fill, .fill, .fill, .fill)
                .columnSpacing(10)
                .padding(16)
            }
            .height(110)
            .shape(.roundedRectangle(14))
            .clipsContent(true)

            SectionTitle("For the hand")

            // Clear, only outlined, it still hears a tap anywhere on it.
            ZStack {
                Text(taps == 0 ? "Tap anywhere here" : taps == 1 ? "Tapped once" : "Tapped \(taps) times")
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
                Filler()
                    .shape(.roundedRectangle(14))
                    .stroke(Palette.outline)
                    .lineWidth(1)
                    .onTapped { taps += 1 }
                    .accessibilityIdentifier("filler.hand")
            }
            .height(80)
        }
        .spacing(12)
    }

    /// A rounded filler with its name in its middle.
    private func tile(_ name: String, _ filler: Filler) -> ZStack {
        ZStack {
            filler
                .shape(.roundedRectangle(10))
            Text(name)
                .fontSize(12)
                .fontWeight(.bold)
                .horizontalAlignment(.center)
                .verticalAlignment(.center)
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("A `Filler` is made of what it is given - a color, a gradient, a blur or glass - in its box's "
            + "shape, outlined where it says so. In a stack it takes the room the others leave, alike with "
            + "spacers; a `Spacer` is the gap.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
