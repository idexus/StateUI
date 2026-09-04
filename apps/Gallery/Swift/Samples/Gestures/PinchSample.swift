import StateUI

/// MAUI: PinchGestureRecognizer.
struct PinchSample: SampleContent {
    @State private var pinch = 1.0
    @State private var reports = 0
    @State private var log: [String] = []

    static let id = "pinch"
    static let title = "Pinch"
    static let summary = "Two fingers moving apart, reported as a change rather than a total."

    // A gesture sample is not put in a scroller: the scroller would claim the
    // drag before the example heard about it. The code below it scrolls
    // instead - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var pinch = 1.0
        @State private var reports = 0
        @State private var log: [String] = []

        VStack {
            // The recognizer is on the Border; the BoxView inside it is what
            // moves. Putting both on one view is what stops a pinch after its
            // first report.
            Border {
                BoxView(Palette.accent)
                    .widthRequest(80)
                    .heightRequest(80)
                    .horizontalOptions(.center)
                    .verticalOptions(.center)
                    .scale(pinch)
            }
            .heightRequest(220)
            .onPinchUpdated { update in
                reports += 1

                // Scale is what changed since the LAST report, so a view being
                // pinched MULTIPLIES rather than assigns - and nothing here
                // waits for .started, which Mac Catalyst never sends.
                if update.status == .running {
                    pinch = max(0.5, min(3, pinch * update.scale))
                }
            }
            // Beside the typed handler, not instead of it: what the host
            // actually sent, before anything reads it - typed values, one per
            // property of the MAUI event.
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

    var example: Element {
        VStack {
            // The recognizer is on the Border; the BoxView inside it is what
            // moves. Putting both on one view is what stops a pinch after its
            // first report - see the notes.
            Border {
                BoxView(Palette.accent)
                    .cornerRadius(10)
                    .widthRequest(80)
                    .heightRequest(80)
                    .horizontalOptions(.center)
                    .verticalOptions(.center)
                    .scale(pinch)
            }
            .stroke(Palette.outline)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(10))
            .heightRequest(220)
            .onPinchUpdated { update in
                reports += 1

                // MAUI's own sample writes `scale += (e.Scale - 1) * startScale`
                // and captures startScale on .started. Multiplying is that same
                // formula with the start taken as the scale RIGHT NOW - and that
                // is the version to write, because .started is not guaranteed:
                // Mac Catalyst's trackpad magnification sends .running and
                // .completed and nothing else.
                if update.status == .running {
                    pinch = max(0.5, min(3, pinch * update.scale))
                }
            }
            // Beside the typed handler, not instead of it: what the host
            // actually sent, before anything reads it - typed values, one per
            // property of the MAUI event. A gesture that stops reporting and a
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
                .horizontalOptions(.center)
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
            Label("MAUI's Scale is RELATIVE - how much has changed since the LAST "
                + "report - so a view being pinched multiplies rather than assigns. "
                + "ScaleOrigin says where the pinch is centred, as a fraction of the "
                + "view.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The four statuses are not a promise. On Mac Catalyst a trackpad "
                + "magnification arrives as .running then .completed - each step of the "
                + "gesture is its own short cycle, and .started never comes at all. A "
                + "pinch that only works when it has seen .started works on a phone and "
                + "not on a laptop.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
