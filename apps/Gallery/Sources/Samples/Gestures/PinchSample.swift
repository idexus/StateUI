import StateUI

/// Two fingers scaling a view, and every report the pinch sends as it arrives.
struct PinchSample: SampleContent, ExampleContent {
    @State private var pinch = 1.0
    @State private var reports = 0
    @State private var log: [String] = []

    static let id = "pinch"
    static let title = "Pinch"
    static let summary = "Two fingers moving apart, reported as a change rather than a total."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // drag before the example heard about it, so the page holds the example
    // still - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var pinch = 1.0
        @State private var reports = 0
        @State private var log: [String] = []

        VStack {
            // The scale and the report count are read here, so every report a
            // pinch makes builds this closure.
            DebugInfoLabel()

            // The recognizer is on the ZStack; the ColorBox inside it is what
            // moves. Putting both on one view is what stops a pinch after its
            // first report.
            ZStack {
                ColorBox(Palette.accent)
                    .width(80)
                    .height(80)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
                    .scale(pinch)
            }
            .style("Card")
            .height(220)
            .onPinchUpdated { update in
                reports += 1

                // Scale is what changed since the LAST report, so a view being
                // pinched MULTIPLIES rather than assigns - and nothing here
                // waits for .started, which a platform need not send.
                if update.phase == .running {
                    pinch = max(0.5, min(3, pinch * update.scale))
                }
            }
            // Beside the typed handler, not instead of it: the report's
            // three values as the view's contract declares them.
            .onEvent(ViewContract.pinchUpdated) { phase, scale, origin in
                let line = "\\(phase)  \\(scale)  \\(origin.x), \\(origin.y)"
                log = (log + [line]).suffix(6).map { $0 }
            }

            Label("Scale \\(Int(pinch * 100))% - \\(reports) report(s)")

            VStack {
                ForEach(Array(log.enumerated()), id: \\.offset) { pair in
                    Label(pair.element)
                }
            }

            Button("Back to life size")
                .onClicked {
                    pinch = 1
                    reports = 0
                    log = []
                }
        }
        """

    var content: any View {
        VStack {
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
            .strokeWidth(1)
            .shape(.roundedRectangle(10))
            .height(220)
            .onPinchUpdated { update in
                reports += 1

                // Multiplying needs no scale captured at the start, and that
                // is what makes it the version to write: .started is not
                // guaranteed, and a trackpad magnification may send .running
                // and .completed and nothing else.
                if update.phase == .running {
                    pinch = max(0.5, min(3, pinch * update.scale))
                }
            }
            // Beside the typed handler, not instead of it: the report's three
            // values as the view's contract declares them - its phase, its
            // scale, and where it is centred. A report of another shape
            // reaches no handler and is said once, which is what tells a
            // gesture that stopped reporting from one this side cannot read.
            .onEvent(ViewContract.pinchUpdated) { phase, scale, origin in
                let line = "\(phase)  \(scale)  \(origin.x), \(origin.y)"
                log = (log + [line]).suffix(6).map { $0 }
            }

            // Per cent rather than a formatted double: String(format:) is
            // Foundation, and this library's one hard rule is to stay away from
            // the parts of it that reach for ICU.
            //
            // The count is here on purpose: a pinch that reports once is a pinch
            // that has been interrupted, and the number says so at a glance.
            Label("Scale \(Int(pinch * 100))% - \(reports) report(s)")
                .fontSize(15)
                .horizontalTextAlignment(.center)

            // What arrived: phase, scale, and where the pinch is centred.
            VStack {
                ForEach(Array(log.enumerated()), id: \.offset) { pair in
                    Label(pair.element)
                        .fontSize(11)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)
                }
            }
            .spacing(2)

            Button("Back to life size")
                .fontSize(13)
                .padding(16, 6)
                .horizontalAlignment(.center)
                .onClicked {
                    pinch = 1
                    reports = 0
                    log = []
                }
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("`scale` is RELATIVE - how much has changed since the LAST report - so "
                + "a view being pinched multiplies rather than assigns. `scaleOrigin` says "
                + "where the pinch is centred, as a fraction of the view.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The four statuses are not a promise. A trackpad magnification may "
                + "arrive as .running then .completed, and .started never comes at all. "
                + "A pinch that only works when it has seen .started works on a phone and "
                + "not on a laptop.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The pinch is heard on the ZStack, and the ColorBox inside it is what "
                + "scales: a view that transforms itself while a gesture runs can cancel "
                + "its own recognizer, and the pinch stops after its first report.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
