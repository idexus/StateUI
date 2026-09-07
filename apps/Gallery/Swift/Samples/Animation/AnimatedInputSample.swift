import StateUI

/// MAUI: Slider.Value and Stepper.Value - the two properties a READER can move,
/// both carried by the host. Two sliders and a stepper, and what differs is who
/// reads the value: the top caption PRINTS it in this body, the two below are
/// CONVERSIONS the host works out on its own frames.
struct AnimatedInputSample: SampleContent {
    /// The TOP slider's value. The caption above the slider PRINTS it, which
    /// makes this view a reader - so every report the thumb makes renders it.
    @State private var volume = 0.2

    /// The BOTTOM slider's value. Nothing here reads it: it is handed on as
    /// `$level` - to the slider, and to the caption's own conversion - and a
    /// binding makes no reader.
    ///
    /// An `AnimatedValue` rather than a plain number, and that is the second
    /// half of what this page shows: it holds where the value is GOING
    /// (`setPoint`) and where it HAS GOT TO (`value`), so a caption converted
    /// off `.value` counts its way along the journey where one written from a
    /// `Double` would jump to the destination at once.
    @State private var level = AnimatedValue(0.2)

    /// The stepper's value, declared the same way - and it needs it more than
    /// the slider does: a Stepper draws two buttons and NO number, so the
    /// caption beside it is the only thing that shows the value at all.
    @State private var count = AnimatedValue(3.0)

    static let id = "animatedInput"
    static let title = "Animated inputs"
    static let summary = "Two sliders over identical states - one read by the page, "
        + "one handed on by `$` and shown by a converted text."

    static let code = """
        // Two IDENTICAL declarations. What differs is who reads them.
        @State private var volume = 0.2     // printed by this body: a reader
        @State private var level = AnimatedValue(0.2)   // handed on: no reader
        @State private var count = AnimatedValue(3.0)

        // Each half is a closure of its own and takes its own reading, which
        // is the instrument the two are told apart by.
        VStack {
            VStack {
                // A GET. This label prints `volume`, which makes THIS closure
                // a reader of it - so every report the thumb makes builds it.
                DebugInfoLabel()

                Label("volume · \\(percent(volume))")

                Slider($volume)
                    .minimum(0)
                    .maximum(1)

                Button("Send the top one").onClicked {
                    // An assignment sends the thumb there under the element's
                    // law, and costs the one render this line asks for.
                    volume = volume < 0.5 ? 1 : 0
                }
            }

            VStack {
                // A BINDING. `$level` is handed to the slider and to the
                // caption's conversion, and nothing prints it - so a drag and
                // a journey build nothing and this reading stays at one.
                DebugInfoLabel()

                // A CONVERTED TEXT. The host works it out from the same image
                // the thumb is walking, on its own frames, so the words keep
                // up with the movement and cost no render.
                Label().text($level.convert { "level · \\(Int(($0.value * 100).rounded()))%" })

                Slider($level)
                    .minimum(0)
                    .maximum(1)

                Button("Send the bottom one").onClicked {
                    try await $level.animateTo(level.setPoint < 0.5 ? 1 : 0,
                                               .eased(900, .cubicInOut))
                }
            }

            VStack {
                DebugInfoLabel()

                Label().text($count.convert { "count · \\(Int($0.value.rounded()))" })

                Stepper($count)
                    .minimum(0)
                    .maximum(20)
                    .increment(1)

                Button("Send the stepper to 12").onClicked {
                    try await $count.animateTo(12, .eased(800, .cubicOut))
                }
            }
        }
        // Every report either control makes, with no render anywhere and no
        // engine written by hand: a conversion IS an engine, one the differ
        // writes.

        /// Whole percent, written by hand - a formatter is Foundation.
        func percent(_ value: Double) -> String {
            "\\(Int((value * 100).rounded()))%"
        }
        """

    var content: Element {
        VStack {
            VStack {
                Label("A GET — this caption prints `volume`, so a drag builds this closure")
                    .fontSize(12)
                    .textColor(Palette.subtle)

                DebugInfoLabel()

                Label("volume · \(percent(volume))")
                    .fontSize(15)

                Slider($volume)
                    .minimum(0)
                    .maximum(1)
                    .minimumTrackColor(Palette.subtle)

                button("Send the top one") {
                    volume = volume < 0.5 ? 1 : 0
                }
            }
            .spacing(10)

            VStack {
                Label("A BINDING — `$level` is handed on and nothing prints it, so this stands still")
                    .fontSize(12)
                    .textColor(Palette.subtle)

                DebugInfoLabel()

                // A CONVERTED TEXT: the host works it out from the same image
                // the thumb is walking, on its own frames, so the words keep
                // up with the movement and cost no render.
                Label()
                    .text($level.convert { "level · \(Int(($0.value * 100).rounded()))%" })
                    .fontSize(15)
                    .textColor(Palette.accent)

                // THE SAME DECLARATION as above, and the same spelling: what
                // differs is that nothing here reads `level` at build.
                Slider($level)
                    .minimum(0)
                    .maximum(1)
                    .minimumTrackColor(Palette.accent)

                button("Send the bottom one") {
                    try await $level.animateTo(level.setPoint < 0.5 ? 1 : 0,
                                               .eased(900, .cubicInOut))
                }
            }
            .spacing(10)

            VStack {
                DebugInfoLabel()

                Label()
                    .text($count.convert { "count · \(Int($0.value.rounded()))" })
                    .fontSize(15)
                    .textColor(Palette.accent)

                Stepper($count)
                    .minimum(0)
                    .maximum(20)
                    .increment(1)
                    .horizontalOptions(.start)

                button("Send the stepper to 12") {
                    try await $count.animateTo(12, .eased(800, .cubicOut))
                }
            }
            .spacing(10)
        }
        .spacing(10)
    }

    var notes: Element? {
        VStack {
            Label("The build count each half takes is what tells them apart. The top "
                + "caption PRINTS `volume`, which makes this page a reader of it, so "
                + "every report the thumb makes renders the page. `level` is handed on "
                + "as `$level` - to the slider and to the caption's conversion - and a "
                + "binding makes no reader: a drag and a journey leave the count where "
                + "it was.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("THAT IS THE WHOLE RULE. A value read in a body - a get - makes the "
                + "body a reader, and a write to the state renders it. A value handed "
                + "on as `$x` - to a control, a modifier, a child or an engine - makes "
                + "no reader, and the host carries it with nothing rebuilt. Where a "
                + "body must show a value that moves, it reads it and pays a render "
                + "per report, or `@State(asks: .every(100))` holds that to ten a "
                + "second; where it need not, a converted text shows it for nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("AND A READING THAT MUST KEEP UP READS `.value`. An `AnimatedValue` "
                + "holds two numbers - `setPoint`, where it is GOING, from the first "
                + "millisecond; `value`, where it HAS GOT TO this frame - so a caption "
                + "converted off `.value` counts its way along the journey where one "
                + "written from the state itself would jump to the destination at once. "
                + "The same declaration is what lets a journey be steered at all: "
                + "`animateTo`, `stop`, a snap.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The stepper needs that more than the slider does: a Stepper draws two "
                + "buttons and NO number, so the caption is the only thing that shows "
                + "the value at all - where a slider has a thumb to watch.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Both readings are CONVERSIONS - `$level.convert { … }` - which is an "
                + "engine the differ writes for you: it runs on the display's own "
                + "frames, from the same image the control is walking, so a drag and a "
                + "journey both cost the arithmetic and no renders.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// Whole percent, written by hand - a formatter is Foundation.
    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(14, 6)
            .onClicked(act)
    }
}
