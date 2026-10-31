import StateUI

/// A press held on a whole view, at the platform's time and at one of its own.
struct HoldSample: SampleContent, ExampleContent {
    // listing: HoldSample
    @State private var taps = 0
    @State private var holds = 0
    @State private var longHolds = 0
    // listing: end

    static let id = "hold"
    static let title = "Hold"
    static let summary = "A press kept still is a hold - and its release no tap."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // press before the example heard about it - see SampleContent.scrolls.
    static let scrolls = false

    // listing: HoldSample
    var body: some View {
        VStack {
            // The counts are read here, so every tap and hold builds this closure.
            DebugInfoLabel()

            ZStack {
                Text("Tap or hold this box")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .style(.card)
            .stroke(Palette.outline)
            .lineWidth(1)
            .shape(.roundedRectangle(10))
            .onTapped { taps += 1 }
            .onHeld { holds += 1 }

            ZStack {
                Text("Hold this one a second")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .style(.card)
            .stroke(Palette.outline)
            .lineWidth(1)
            .shape(.roundedRectangle(10))
            .onHeld(minimum: .seconds(1)) { longHolds += 1 }

            Text("Tapped \(taps), held \(holds), held a second \(longHolds)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Android and Windows wait the system's own time for both boxes; "
            + "Windows holds for a finger or a pen, not the mouse.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
