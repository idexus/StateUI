import StateUI

/// A tap and a double tap on a whole view.
struct TapSample: SampleContent, ExampleContent {
    // listing: TapSample
    @State private var taps = 0
    // listing: end

    static let id = "tap"
    static let title = "Tap"
    static let summary = "The whole view answers, not a button inside it."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // drag before the example heard about it, so the page holds the example
    // still - see SampleContent.scrolls.
    static let scrolls = false

    // listing: TapSample
    var body: some View {
        VStack {
            // The count is read here, so every tap builds this closure.
            DebugInfoLabel()

            ZStack {
                Text("Tap anywhere on this box")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .style("Card")
            .stroke(Palette.accent)
            .lineWidth(1)
            .shape(.roundedRectangle(10))
            .onTapped { taps += 1 }

            ZStack {
                Text("Double-tap this one to reset")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .style("Card")
            .stroke(Palette.outline)
            .lineWidth(1)
            .shape(.roundedRectangle(10))
            .onTapped(count: 2) { taps = 0 }

            Text("Tapped \(taps) time(s)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Any view answers a tap: every card on a group's page is a view with "
            + "`.onTapped` on it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
