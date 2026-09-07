import StateUI

/// MAUI: Slider.Value and Stepper.Value - the two properties a READER can move,
/// both carried by the host. Two sliders over two IDENTICAL declarations, and
/// the one thing that differs is who reads the value: the top caption reads it
/// in this body, the bottom one is handed on as `$level` and read by an engine.
struct AnimatedInputSample: SampleContent {
    /// The TOP slider's value. The caption above the slider PRINTS it, which
    /// makes this view a reader - so every report the thumb makes renders it.
    @State private var volume = 0.2

    /// The BOTTOM slider's value, declared exactly the same way. Nothing here
    /// reads it: it is handed on as `$level`, to the slider and to an engine,
    /// and a binding makes no reader.
    @State private var count = 3.0

    /// The stepper's value, handed on the same way.
    @State private var level = 0.2

    /// What the bottom slider reads, worked out by an engine following `level`.
    /// A driven text, so showing it costs no render either.
    @State private var reading = "level · 20%"

    /// What the stepper reads. A Stepper draws its two buttons and NO number,
    /// so the number is a driven text, written by the same engine.
    @State private var counted = "count · 3"

    static let id = "animatedInput"
    static let title = "Animated inputs"
    static let summary = "Two sliders over identical states - one read by the page, "
        + "one handed on by `$` and shown by an engine."

    static let code = """
        // Two IDENTICAL declarations. What differs is who reads them.
        @State private var volume = 0.2     // printed by this body: a reader
        @State private var level = 0.2      // handed on as $level: no reader
        @State private var count = 3.0
        @State private var reading = "level · 20%"
        @State private var counted = "count · 3"

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
                // engine, and nothing prints it - so a drag and a journey
                // build nothing and this reading stays at one.
                DebugInfoLabel()

                Label().text($reading)

                Slider($level)
                    .minimum(0)
                    .maximum(1)
                    .motion(.eased(900, .cubicInOut))

                Button("Send the bottom one").onClicked {
                    level = level < 0.5 ? 1 : 0
                }
            }

            VStack {
                DebugInfoLabel()

                Label().text($counted)

                Stepper($count)
                    .minimum(0)
                    .maximum(20)
                    .increment(1)
                    .motion(.eased(800, .cubicOut))

                Button("Send the stepper to 12").onClicked { count = 12 }
            }
        }
        // Every report either control makes, with no render anywhere. ONE
        // engine for the two of them: it runs when either state moves, and a
        // text written unchanged crosses as nothing.
        .engine(following: $level, $count) { _ in
            reading = "level · \\(percent(level))"
            counted = "count · \\(Int(count.rounded()))"
        }

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

                Label()
                    .text($reading)
                    .fontSize(15)
                    .textColor(Palette.accent)

                // THE SAME DECLARATION as above, and the same spelling: what
                // differs is that nothing here reads `level` at build.
                Slider($level)
                    .minimum(0)
                    .maximum(1)
                    .minimumTrackColor(Palette.accent)
                    .motion(.eased(900, .cubicInOut))

                button("Send the bottom one") {
                    level = level < 0.5 ? 1 : 0
                }
            }
            .spacing(10)

            VStack {
                DebugInfoLabel()

                Label()
                    .text($counted)
                    .fontSize(15)
                    .textColor(Palette.accent)

                Stepper($count)
                    .minimum(0)
                    .maximum(20)
                    .increment(1)
                    .horizontalOptions(.start)
                    .motion(.eased(800, .cubicOut))

                button("Send the stepper to 12") { count = 12 }
            }
            .spacing(10)
        }
        .spacing(10)
        .engine(following: $level, $count) { _ in
            reading = "level · \(percent(level))"
            counted = "count · \(Int(count.rounded()))"
        }
    }

    var notes: Element? {
        VStack {
            Label("Two sliders over two IDENTICAL declarations - `@State private var "
                + "volume = 0.2` and `@State private var level = 0.2` - and the build "
                + "count each half takes is what tells them apart. The top caption PRINTS "
                + "`volume`, which makes this page a reader of it, so every report the "
                + "thumb makes renders the page. `level` is handed on as `$level`, to "
                + "the slider and to an engine, and a binding makes no reader: a drag "
                + "and a journey leave the count where it was.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("THAT IS THE WHOLE RULE. A value read in a body - a get - makes the "
                + "body a reader, and a write to the state renders it. A value handed "
                + "on as `$x` - to a control, a modifier, a child or an engine - makes "
                + "no reader, and the host carries it with nothing rebuilt. Where a "
                + "body must show a value that moves, it reads it and pays a render "
                + "per report, or `@State(asks: .every(100))` holds that to ten a "
                + "second; where it need not, an engine writes a driven text.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Send moves the thumb under the slider's own `.motion`, and the "
                + "reading under the bottom slider jumps to the destination at once: "
                + "a `Double` answers where the value is GOING. To read where it IS "
                + "while it travels, or to steer the journey - `animateTo`, `stop`, a "
                + "snap - declare an `AnimatedValue`, which Reading a driven state "
                + "shows.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Both readings are driven TEXTS, written by one engine following the "
                + "two states. It runs on the display's own frames, so a drag and a "
                + "journey both cost the arithmetic and no renders; the stepper's "
                + "number is the same answer, a Stepper drawing no number of its own.")
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
