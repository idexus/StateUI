import StateUI

/// The model and the screen are two different readings, and this is the sample
/// that shows both at once: the flying state stands at the target from the
/// first millisecond, and a SECOND state is written with what the control is
/// actually showing, as often as the author asked and no oftener.
struct WatchedFlightSample: SampleContent {
    /// Where the width is GOING. Armed by being written from its binding.
    @State private var width = 60.0

    /// Where the bar has GOT to - the host writes this one.
    @State private var shown = 60.0

    /// How many milliseconds of the walk between readings. The whole point of
    /// the parameter is that this is the author's decision: the walk's frames
    /// are the platform's, and no interface needs sixty readings a second.
    @State private var cadence: UInt = 100

    static let id = "watched-flight"
    static let title = "Watching a walk"
    static let summary = "The state holds the target; a second state holds what is on screen."

    static let code = """
        @State private var width = 60.0    // where it is going
        @State private var shown = 60.0    // where it has got to
        @State private var cadence: UInt = 100

        VStack {
            // The bar itself: one armed property, and the flight moves it.
            Border { }
                .widthRequest($width)
                .heightRequest(28)

            Label("going to \\(Int(width)) — showing \\(Int(shown))")

            HStack {
                Button("Grow")
                    .onClicked {
                        try await $width.animateTo(
                            300, length: 1600, easing: .cubicOut,
                            reporting: $shown, every: cadence)
                    }

                Button("Shrink")
                    .onClicked {
                        try await $width.animateTo(
                            60, length: 1600, easing: .cubicIn,
                            reporting: $shown, every: cadence)
                    }

                // Stopping writes what the control had REACHED back into the
                // flying state, so the tree and the screen agree again.
                Button("Stop").onClicked { try await $width.stop() }
            }

            HStack {
                Button("every 50ms").onClicked { cadence = 50 }
                Button("every 100ms").onClicked { cadence = 100 }
                Button("every 400ms").onClicked { cadence = 400 }
            }
        }
        """

    var content: Element {
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

            Label("going to \(Int(width)) — showing \(Int(shown))")
                .fontSize(17)

            HStack {
                Button("Grow")
                    .backgroundColor(Palette.accent)
                    .cornerRadius(8)
                    .padding(16, 8)
                    .onClicked {
                        try await $width.animateTo(
                            300, length: 1600, easing: .cubicOut,
                            reporting: $shown, every: cadence)
                    }

                Button("Shrink")
                    .backgroundColor(Palette.accent)
                    .cornerRadius(8)
                    .padding(16, 8)
                    .onClicked {
                        try await $width.animateTo(
                            60, length: 1600, easing: .cubicIn,
                            reporting: $shown, every: cadence)
                    }

                Button("Stop")
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .backgroundColor(.transparent)
                    .textColor(Palette.subtle)
                    .cornerRadius(8)
                    .padding(16, 8)
                    .onClicked { try await $width.stop() }
            }
            .spacing(10)

            HStack {
                cadenceButton(50)
                cadenceButton(100)
                cadenceButton(400)
            }
            .spacing(8)
        }
        .spacing(12)
    }

    /// One of the three cadences, drawn as chosen or not - the sample's own
    /// look, which is why it is not in the listing above.
    private func cadenceButton(_ milliseconds: UInt) -> Element {
        Button("every \(milliseconds)ms")
            .fontSize(12)
            .backgroundColor(cadence == milliseconds ? Palette.accent : .transparent)
            .textColor(cadence == milliseconds ? Palette.onAccent : Palette.subtle)
            .borderColor(Palette.outline)
            .borderWidth(1)
            .cornerRadius(8)
            .padding(12, 6)
            .onClicked { cadence = milliseconds }
    }

    var notes: Element? {
        VStack {
            Label("A flight gives the state its TARGET at once and the host walks the "
                + "control there, so \"going to\" changes the instant a button is pressed "
                + "while the bar takes 1600ms. That is the model: the tree always "
                + "describes where a value is heading, which is what makes a rebuild "
                + "in the middle of a walk say nothing at all.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Which leaves the other question - what is on screen RIGHT NOW - and "
                + "reporting: is the answer. It takes a second piece of state, and the "
                + "host writes it every `every:` milliseconds OF THE WALK, not of the "
                + "wall clock: change the cadence and the reading visibly coarsens while "
                + "the bar moves exactly as before. Never pass the flying state itself: "
                + "an assignment to an armed property is what ENDS a walk, which is what "
                + "Stop uses on purpose.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The cadence is stated rather than assumed because every reading is a "
                + "crossing and a render. Sixty a second for a number nobody can read "
                + "that fast was measured at about 60ms of the UI thread per second, "
                + "which is why it is not the default and not available: ten a second is "
                + "what a number on screen needs. A walk nobody watches crosses the "
                + "boundary exactly twice - once to say where it is going, once to say "
                + "it arrived.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
