import StateUI

/// Two fingers scaling a view, and every report the pinch sends as it arrives.
struct PinchSample: SampleContent, ExampleContent {
    // listing: PinchSample
    @State private var pinch = 1.0
    @State private var reports = 0
    // listing: end

    static let id = "pinch"
    static let title = "Pinch"
    static let summary = "Two fingers moving apart, reported as a change rather than a total."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // drag before the example heard about it, so the page holds the example
    // still - see SampleContent.scrolls.
    static let scrolls = false

    // listing: PinchSample
    var body: some View {
        VStack {
            // The scale and the report count are read here, so every report a
            // pinch makes builds this closure.
            DebugInfoLabel()

            // The recognizer is on the ZStack; the ColorBox inside it is what
            // moves. Putting both on one view is what stops a pinch after its
            // first report - see the notes.
            ZStack {
                ColorBox(Palette.accent)
                    .cornerRadius(10)
                    .width(80)
                    .height(80)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
                    .scale(pinch)
            }
            .style("Card")
            .stroke(Palette.outline)
            .lineWidth(1)
            .shape(.roundedRectangle(10))
            .height(220)
            .onPinchUpdated { update in
                reports += 1

                // Multiplying needs no scale captured at the start, and that
                // is what makes it the version to write: .began is not
                // guaranteed, and a trackpad magnification may send .changed
                // and .ended and nothing else.
                if update.phase == .changed {
                    pinch = max(0.5, min(3, pinch * update.scale))
                }
            }

            // Per cent rather than a formatted double: String(format:) is
            // Foundation, which the library never imports.
            //
            // The count is here on purpose: a pinch that reports once is a pinch
            // that has been interrupted, and the number says so at a glance.
            Text("Scale \(Int(pinch * 100))% - \(reports) report(s)")
                .fontSize(15)
                .horizontalTextAlignment(.center)

            Button("Back to life size")
                .fontSize(13)
                .padding(horizontal: 16, vertical: 6)
                .horizontalAlignment(.center)
                .onClicked {
                    pinch = 1
                    reports = 0
                }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("`scale` is RELATIVE - how much has changed since the LAST report - so "
                + "a view being pinched multiplies rather than assigns. `scaleOrigin` says "
                + "where the pinch is centred, as a fraction of the view.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The four statuses are not a promise. A trackpad magnification may "
                + "arrive as .changed then .ended, and .began never comes at all. "
                + "A pinch that only works when it has seen .began works on a phone and "
                + "not on a laptop.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The pinch is heard on the ZStack, and the ColorBox inside it is what "
                + "scales: a view that transforms itself while a gesture runs can cancel "
                + "its own recognizer, and the pinch stops after its first report.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
