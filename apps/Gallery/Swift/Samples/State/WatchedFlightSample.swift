import StateUI

/// Where a value is GOING and where it HAS GOT TO are two readings, and a driven
/// state holds both: `setPoint` is the destination from the first millisecond,
/// `value` is what is on the screen this frame.
struct WatchedFlightSample: SampleContent {
    /// The bar's width, driven - so both readings live here and neither costs
    /// a render.
    @State(describing: .none) private var width = AnimatedValue(60.0)

    /// What the caption says, worked out by an engine following the width.
    @State(describing: .none) private var caption = "going to 60 — showing 60"

    /// How far apart the readings are, as a bar of its own - which is the whole
    /// point made visible.
    @State(describing: .none) private var gap = AnimatedValue(0.0)

    static let id = "watched-flight"
    static let title = "Reading a driven state"
    static let summary = "One state holds where the value is going and where it has got to."

    static let code = """
        @State(describing: .none) private var width = AnimatedValue(60.0)
        @State(describing: .none) private var caption = "going to 60 — showing 60"
        @State(describing: .none) private var gap = AnimatedValue(0.0)

        VStack {
            // The bar: one driven property, and the host moves it.
            Border { }
                .widthRequest($width)
                .heightRequest(28)

            // The two readings, written every frame by the engine below.
            Label().text($caption)

            HStack {
                Button("Grow").onClicked {
                    try await $width.animateTo(300, .eased(1600, .cubicOut))
                }

                Button("Shrink").onClicked {
                    try await $width.animateTo(60, .eased(1600, .cubicIn))
                }

                // Stopping leaves the value where it stands, and the setpoint
                // is mirrored onto it - so both readings agree again.
                Button("Stop").onClicked { $width.stop() }
            }
        }
        // Reads the driven state and writes two more, sixty times a second,
        // with no render anywhere.
        .engine(following: $width) { _ in
            caption = "going to \\(Int(width.setPoint)) — showing \\(Int(width.value))"
            gap.value = abs(width.setPoint - width.value)
        }
        """

    var example: Element {
        VStack {
            Border {
                Label("")
            }
            .widthRequest($width)
            .heightRequest(28)
            .background(.solidColor(Palette.accent))
            .strokeShape(.roundRectangle(8))
            .strokeThickness(0)
            .horizontalOptions(.start)

            Label()
                .text($caption)
                .fontSize(17)

            Label("how far apart the two readings are")
                .fontSize(12)
                .textColor(Palette.subtle)

            // The SAME arithmetic drawn: the distance between where the value
            // is going and where it is. It is widest the moment a button is
            // pressed and nought when the bar arrives.
            Border {
                Label("")
            }
            .widthRequest($gap)
            .heightRequest(10)
            .background(.solidColor(Palette.subtle))
            .strokeShape(.roundRectangle(5))
            .strokeThickness(0)
            .horizontalOptions(.start)

            HStack {
                Button("Grow")
                    .backgroundColor(Palette.accent)
                    .cornerRadius(8)
                    .padding(16, 8)
                    .onClicked {
                        try await $width.animateTo(300, .eased(1600, .cubicOut))
                    }

                Button("Shrink")
                    .backgroundColor(Palette.accent)
                    .cornerRadius(8)
                    .padding(16, 8)
                    .onClicked {
                        try await $width.animateTo(60, .eased(1600, .cubicIn))
                    }

                Button("Stop")
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .backgroundColor(.transparent)
                    .textColor(Palette.subtle)
                    .cornerRadius(8)
                    .padding(16, 8)
                    .onClicked { $width.stop() }
            }
            .spacing(10)
        }
        .spacing(12)
        .engine(following: $width) { _ in
            caption = "going to \(Int(width.setPoint)) — showing \(Int(width.value))"
            gap.value = abs(width.setPoint - width.value)
        }
    }

    var notes: Element? {
        VStack {
            Label("One state, two readings. `width.setPoint` is 300 the instant Grow is "
                + "pressed; `width.value` is what the bar is actually showing this "
                + "frame. The grey bar under the caption is the distance between them, "
                + "widest at the start and nought on arrival.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Both numbers are read by an engine, which runs on the display's own "
                + "frames and writes two more driven states - the caption's words and "
                + "the grey bar's width. Nothing on this page is described while any of "
                + "it moves, so a 1600ms journey costs no renders at all.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Stop leaves the value where it stands and brings the setpoint to "
                + "meet it, so the two readings agree again and the grey bar closes. "
                + "Press Grow and then Stop half way: the caption's first number "
                + "becomes the second.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("There is no cadence to choose. An engine runs once a frame whatever "
                + "it reads, and what it writes is another driven state - so asking for "
                + "a reading sixty times a second costs what asking for one twice a "
                + "second would.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
