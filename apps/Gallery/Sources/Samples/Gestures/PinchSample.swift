import StateUI

/// Two fingers scaling and turning a view, and every report they send as it arrives.
struct PinchSample: SampleContent, ExampleContent {
    // listing: PinchSample
    @State private var pinch = 1.0
    @State private var pinchedFrom = 1.0
    @State private var turn = 0.0
    @State private var turnedFrom = 0.0
    @State private var reports = 0
    // listing: end

    static let id = "pinch"
    static let title = "Pinch and turn"
    static let summary = "Two fingers spreading and turning a view, each told from where they began."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // drag before the example heard about it, so the page holds the example
    // still - see SampleContent.scrolls.
    static let scrolls = false

    // listing: PinchSample
    var body: some View {
        VStack {
            // The scale, the angle and the report count are read here, so every
            // report the fingers make builds this closure.
            DebugInfoLabel()

            // The recognizer is on the ZStack; the rectangle inside it is what
            // moves. Putting both on one view is what stops a pinch after its
            // first report - see the notes.
            ZStack {
                Rectangle()
                    .fill(Palette.accent)
                    .cornerRadius(10)
                    .width(80)
                    .height(80)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
                    .scale(pinch)
                    .rotation(turn)
            }
            .style(.card)
            .stroke(Palette.outline)
            .lineWidth(1)
            .shape(.roundedRectangle(10))
            .height(220)
            .onPinchUpdated { update in
                reports += 1

                // The spread since the pinch began scales the size it had
                // then.
                if update.phase == .began { pinchedFrom = pinch }
                pinch = max(0.5, min(3, pinchedFrom * update.scale))
            }
            .onRotationUpdated { update in
                reports += 1

                // The angle since the fingers began turns the view from where
                // it stood then.
                if update.phase == .began { turnedFrom = turn }
                turn = turnedFrom + update.angle
            }

            // Per cent rather than a formatted double: String(format:) is
            // Foundation, which this sample does not import.
            //
            // The count is here on purpose: a pinch that reports once is a pinch
            // that has been interrupted, and the number says so at a glance.
            Text("Scale \(Int(pinch * 100))%, turned \(Int(turn))° - \(reports) report(s)")
                .fontSize(15)
                .horizontalTextAlignment(.center)

            Button("Back as it was")
                .horizontalAlignment(.center)
                .onClicked {
                    pinch = 1
                    turn = 0
                    reports = 0
                }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("`scale` is how far the fingers have spread since the pinch began, and "
                + "`angle` how far they have turned, in degrees clockwise, so a view "
                + "scales the size and turns from the angle it had then. `scaleOrigin` "
                + "says where the pinch is centered, as a fraction of the view; each "
                + "report's `velocity` how fast it goes. On a desktop, drag with ⌥ (Alt) "
                + "held for two fingers.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Each begins with .began, goes on with .changed and ends with .ended "
                + "or .cancelled, on every host - fingers and a trackpad alike - and its "
                + "end carries where it reached.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The fingers are heard on the ZStack, and the rectangle inside it is "
                + "what moves: a view that transforms itself while a gesture runs can "
                + "cancel its own recognizer, and the gesture stops after its first report.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
