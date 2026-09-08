import StateUI

/// Where a value is GOING and where it HAS GOT TO are two readings, and a driven
/// state holds both: `setPoint` is the destination from the first millisecond,
/// `value` is what is on the screen this frame.
struct DrivenReadingSample: SampleContent {
    /// The bar's width, driven - so both readings live here and neither costs
    /// a render.
    @State private var width = AnimatedValue(60.0)


    static let id = "driven-reading"
    static let title = "Reading a driven state"
    static let summary = "One state holds where the value is going and where it has got to."

    static let code = """
        @State private var width = AnimatedValue(60.0)

        VStack {
            // NOTHING in this closure reads: the bar is a channel and both
            // readings are CONVERSIONS of it, worked out by the host on its own
            // frames. So this stays at one build while the numbers move sixty
            // times a second.
            DebugInfoLabel()

            // The bar: one driven property, and the host moves it.
            Border { }
                .widthRequest($width)
                .heightRequest(28)

            // The two readings, off ONE state: `setPoint` is where the value
            // is going and `value` where it has got to.
            Label($width.convert {
                "going to \\(Int($0.setPoint)) — showing \\(Int($0.value))"
            })

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

        """

    var content: Element {
        VStack {
            DebugInfoLabel()

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
                .text($width.convert {
                    "going to \(Int($0.setPoint)) — showing \(Int($0.value))"
                })
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
            .widthRequest($width.convert { abs($0.setPoint - $0.value) })
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
    }

    var notes: Element? {
        VStack {
            Label("One state, two readings. `width` is 300 the instant Grow is "
                + "pressed; `width.value` is what the bar is actually showing this "
                + "frame. The grey bar under the caption is the distance between them, "
                + "widest at the start and nought on arrival.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Both numbers, and the grey bar's width, are CONVERSIONS of the one "
                + "state: `$width.convert { … }` reads `setPoint` and `value` off it "
                + "and the host works the answer out on its own frames. Nothing on this "
                + "page reads `width` in a body, so a 1600ms journey costs no renders at "
                + "all; printed by a body it would cost one per frame, that body being a "
                + "reader.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Stop leaves the value where it stands and brings the setpoint to "
                + "meet it, so the two readings agree again and the grey bar closes. "
                + "Press Grow and then Stop half way: the caption's first number "
                + "becomes the second.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("There is no cadence to choose. A conversion is worked out once a "
                + "frame, and what it answers is another driven state - so asking for "
                + "a reading sixty times a second costs what asking for one twice a "
                + "second would.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
