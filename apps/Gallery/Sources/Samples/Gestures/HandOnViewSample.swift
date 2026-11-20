import StateUI

/// The hand on a view itself: a card that answers a press, and a chip the hand takes.
struct HandOnViewSample: SampleContent, ExampleContent {
    static let id = "handOnView"
    static let title = "The hand on a view"
    static let summary = "A view answers a press and is taken by the hand - with no state, no handler."

    // The chip is dragged, so the example is not put in a scroller: the page's would claim the drag first - see
    // SampleContent.scrolls.
    static let scrolls = false

    // listing: HandOnViewSample
    var body: some View {
        VStack {
            // The hand builds no view: the label says so.
            DebugInfoLabel()

            // A PRESS GROWS THE CARD A LITTLE, PULLS IT TOWARD ITSELF AND STRETCHES IT THE WAY IT PULLS - on a
            // spring of its own, so nothing jumps as the press goes down or lifts.
            ZStack {
                Rectangle()
                    .fill(Palette.accent)
                    .cornerRadius(16)
                Text("Press me")
                    .fontWeight(.semibold)
                    .textColor(Palette.onBrand)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
            }
            .width(220)
            .height(96)
            .horizontalAlignment(.center)
            .interaction(.elasticPress(maximumOffset: 10, scale: 1.03, maximumScale: 1.08))
            .accessibilityIdentifier("pressed")

            // THE HAND TAKES THE CHIP ITSELF: it stays under the hand any way, and goes back where the stack
            // puts it once let go - on the spring its body names.
            ZStack {
                Rectangle()
                    .fill(Palette.raised)
                    .cornerRadius(22)
                Text("Drag me")
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
            }
            .width(140)
            .height(44)
            .horizontalAlignment(.center)
            .interaction(.drag(.both))
            .layoutBody(.onChange(response: .milliseconds(320), damping: 0.7))
            .accessibilityIdentifier("dragged")
        }
        .spacing(28)
    }
    // listing: end

    var notes: (any View)? {
        Text("Press the card and move over it: it grows, leans toward the press and stretches the way it is "
            + "pulled. Drag the chip anywhere and let go: it comes back. Neither moves a state - "
            + "`.interaction(.elasticPress())` and `.interaction(.drag(.both))` are the whole of it; the chip's "
            + "`.layoutBody` is the spring it comes back on.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
