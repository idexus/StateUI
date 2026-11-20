import StateUI

/// Where a value is GOING and where it HAS GOT TO are two readings: the state
/// itself is the destination from the first millisecond, and its journey's
/// sample is what the host shows on this frame.
struct DrivenReadingSample: SampleContent, ExampleContent {
    // listing: DrivenReadingSample
    /// The bar's width, driven - so neither reading costs a render.
    @State private var width = 60.0

    /// What the engine following the bar's journey writes: the caption's
    /// words, and how far apart the two readings are. The host shows both;
    /// no body reads them.
    @State private var readings = "going to 60 — showing 60"
    @State private var apart = 0.0
    // listing: end

    static let id = "driven-reading"
    static let title = "Reading a driven state"
    static let summary = "One state holds where the value is going and where it has got to."

    // listing: DrivenReadingSample
    var body: some View {
        VStack {
            // NOTHING in this closure reads: the bar is a channel, and both
            // readings are written by an engine following its journey on the
            // host's own frames. So this stays at one build while the numbers
            // move on every frame.
            DebugInfoLabel()

            // The bar: one driven property, and the host moves it.
            ZStack {
                Text("")
            }
            .style(.card)
            .width($width)
            .height(28)
            .background(Palette.accent)
            .shape(.roundedRectangle(8))
            .lineWidth(0)
            .horizontalAlignment(.start)

            // The two readings, off ONE sample of the journey: `destination`
            // is where the host is taking the value and `value` where it has
            // got to, both of the same frame. The distance between them is a
            // number worked out, not chosen: it is snapped, never animated.
            Text($readings)
                .fontSize(17)
                .engine(following: $width.journey) { _ in
                    guard let sample = $width.journey.sample else { return }
                    readings = "going to \(Int(sample.destination)) — showing \(Int(sample.value))"
                    $apart.journey.snap(to: abs(sample.destination - sample.value))
                }

            Text("how far apart the two readings are")
                .fontSize(12)
                .textColor(Palette.subtle)

            // The SAME arithmetic drawn: the distance between where the value
            // is going and where it is. It is widest the moment a button is
            // pressed and nought when the bar arrives.
            ZStack {
                Text("")
            }
            .style(.card)
            .width($apart)
            .height(10)
            .background(Palette.subtle)
            .shape(.roundedRectangle(5))
            .lineWidth(0)
            .horizontalAlignment(.start)

            HStack {
                Button("Grow")
                    .onClicked {
                        $width.journey.move(to: 300, .eased(.milliseconds(1600)))
                    }

                Button("Shrink")
                    .onClicked {
                        $width.journey.move(to: 60, .eased(.milliseconds(1600), curve: .cubicIn))
                    }

                // Stopping leaves the value where it stands, and the
                // destination is mirrored onto it - so both readings agree again.
                Button("Stop")
                    .onClicked { $width.journey.stop() }
            }
            .spacing(10)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("One state, two readings. `width` is 300 the instant Grow is "
                + "pressed; `$width.journey.sample` is what the bar is actually showing this "
                + "frame. The gray bar under the caption is the distance between them, "
                + "widest at the start and nought on arrival.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Both numbers, and the gray bar's width, are written by one ENGINE "
                + "FOLLOWING THE JOURNEY: `.engine(following: $width.journey) { … }` runs "
                + "whenever the sample changes and reads `destination` and `value` off "
                + "it, both of one frame. Nothing on this page reads `width` in a body, "
                + "so a 1600ms journey costs no renders at all: a body printing `width` "
                + "would be built once per press, and one printing "
                + "`$width.journey.sample` once per frame.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Stop leaves the value where it stands and brings the destination to "
                + "meet it, so the two readings agree again and the gray bar closes. "
                + "Press Grow and then Stop half way: the caption's first number "
                + "becomes the second.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("There is no cadence to choose. The engine runs on every frame the "
                + "value moves, and what it writes are driven states - so however often "
                + "the readings change, they cost no render. A conversion, "
                + "`$width.convert { … }`, is another thing: it is worked out from where "
                + "the value is GOING, once a write.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
