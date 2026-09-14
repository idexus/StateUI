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

            // The recognizer is on the Border; the BoxView inside it is what
            // moves. Putting both on one view is what stops a pinch after its
            // first report.
            Border {
                BoxView(Palette.accent)
                    .width(80)
                    .height(80)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
                    .scale(pinch)
            }
            .height(220)
            .onPinchUpdated { update in
                reports += 1

                // Scale is what changed since the LAST report, so a view being
                // pinched MULTIPLIES rather than assigns - and nothing here
                // waits for .started, which a platform need not send.
                if update.status == .running {
                    pinch = max(0.5, min(3, pinch * update.scale))
                }
            }
            // Beside the typed handler, not instead of it: what the host
            // actually sent, before anything reads it - typed values, one per
            // field of the report.
            .onEvent(.pinchUpdated) { payload in
                let line = payload.map { "\\($0)" }.joined(separator: "  ")
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

            // The recognizer is on the Border; the BoxView inside it is what
            // moves. Putting both on one view is what stops a pinch after its
            // first report - see the notes.
            Border {
                BoxView(Palette.accent)
                    .cornerRadius(10)
                    .width(80)
                    .height(80)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
                    .scale(pinch)
            }
            .stroke(Palette.outline)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(10))
            .height(220)
            .onPinchUpdated { update in
                reports += 1

                // Multiplying needs no scale captured at the start, and that
                // is what makes it the version to write: .started is not
                // guaranteed, and a trackpad magnification may send .running
                // and .completed and nothing else.
                if update.status == .running {
                    pinch = max(0.5, min(3, pinch * update.scale))
                }
            }
            // Beside the typed handler, not instead of it: what the host
            // actually sent, before anything reads it - typed values, one per
            // field of the report. A gesture that stops reporting and a
            // payload this side cannot read look identical from the outside,
            // and this is what tells them apart.
            .onEvent(.pinchUpdated) { payload in
                let line = payload.map { "\($0)" }.joined(separator: "  ")
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

            // What arrived, verbatim: status, scale, and where the pinch is
            // centred.
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

            Label("The pinch is heard on the Border, and the BoxView inside it is what "
                + "scales: a view that transforms itself while a gesture runs can cancel "
                + "its own recognizer, and the pinch stops after its first report.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
