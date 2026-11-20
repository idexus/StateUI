import StateUI

/// A long press on a whole view, at the platform's time and at one of its own.
struct LongPressSample: SampleContent, ExampleContent {
    // listing: LongPressSample
    @State private var taps = 0
    @State private var presses = 0
    @State private var longer = 0
    // listing: end

    static let id = "longPress"
    static let title = "Long press"
    static let summary = "A press kept still is a long press - and its release no tap."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // press before the example heard about it - see SampleContent.scrolls.
    static let scrolls = false

    // listing: LongPressSample
    var body: some View {
        VStack {
            // The counts are read here, so every tap and long press builds this closure.
            DebugInfoLabel()

            ZStack {
                Text("Tap or long press this box")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .style(.card)
            .stroke(Palette.outline)
            .lineWidth(1)
            .shape(.roundedRectangle(10))
            .onTapped { taps += 1 }
            .onLongPressed { presses += 1 }

            ZStack {
                Text("Press this one for a second")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .style(.card)
            .stroke(Palette.outline)
            .lineWidth(1)
            .shape(.roundedRectangle(10))
            .onLongPressed(minimum: .seconds(1)) { longer += 1 }

            Text("Tapped \(taps), long pressed \(presses), for a second \(longer)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Android and Windows wait the system's own time for both boxes; "
            + "Windows tells a long press of a finger or a pen, not the mouse.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
