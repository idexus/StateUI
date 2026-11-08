import StateUI

/// A view moved, turned or sized takes its tap where it is drawn.
struct DrawnAwaySample: SampleContent, ExampleContent {
    // listing: DrawnAwaySample
    @State private var turned = 0
    @State private var moved = 0
    @State private var grown = 0
    // listing: end

    static let id = "drawnAway"
    static let title = "Drawn away"
    static let summary = "A view moved, turned or sized answers where it is drawn, not where it was laid out."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // press before the example heard about it - see SampleContent.scrolls.
    static let scrolls = false

    // listing: DrawnAwaySample
    var body: some View {
        VStack {
            // The counts are read here, so every tap builds this closure.
            DebugInfoLabel()

            // Turned: its corners stand outside the frame it was laid out in, and a tap on a corner is its own.
            card("Tap the turned card")
                .rotation(20)
                .onTapped { turned += 1 }
                .accessibilityIdentifier("drawnAway.turned")

            // Moved a card's width to the right: a tap where it stands counts, one where its frame lies does not.
            card("Tap the moved card")
                .translationX(120)
                .onTapped { moved += 1 }
                .accessibilityIdentifier("drawnAway.moved")

            // Grown by half: a tap on the grown edge counts.
            card("Tap the grown card")
                .scale(1.5)
                .onTapped { grown += 1 }
                .accessibilityIdentifier("drawnAway.grown")

            Text("Turned \(turned), moved \(moved), grown \(grown)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
                .accessibilityIdentifier("drawnAway.counts")
        }
        .spacing(36)
    }

    private func card(_ words: String) -> some View {
        ZStack {
            Text(words)
                .fontSize(15)
                .padding(20)
                .horizontalTextAlignment(.center)
        }
        .width(220)
        .style(.card)
        .stroke(Palette.outline)
        .lineWidth(1)
        .shape(.roundedRectangle(10))
    }
    // listing: end

    var notes: (any View)? {
        Text("Every view of StateUI's own takes a press where it is drawn. A control the platform tracks itself - "
            + "a button of the Mac's - is found where it is drawn and follows its click by the frame it was laid out in.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
