import StateUI

/// A slider's value and a stepper's - the two properties a USER can move,
/// both carried by the host. Two sliders and a stepper, and what differs is who
/// reads the value: the top caption PRINTS it in this body, the two below are
/// written by ENGINES following the value's journey on the display's frames.
struct AnimatedInputSample: SampleContent, ExampleContent {
    // listing: AnimatedInputSample
    /// The TOP slider's value. The caption above the slider PRINTS it, which
    /// makes the closure it sits in a reader - so every report the thumb
    /// makes builds that closure again, and nothing around it.
    @State private var volume = 0.2   // printed by this body: a reader

    /// The BOTTOM slider's value. Nothing here reads it: it is handed on as
    /// `$level` - to the slider, and to the caption's engine as its journey -
    /// and a binding makes no reader.
    ///
    /// Its JOURNEY is the second half of what this page shows: `level` is
    /// where the value is GOING and `$level.journey.sample` where it HAS GOT
    /// TO, so a caption written from the sample counts its way along it
    /// where one converted from the state would jump to the destination at
    /// once.
    @State private var level = 0.2   // handed on: no reader

    /// What the two captions say, written by their engines and shown by the
    /// host: no body reads them.
    @State private var levelWords = "level · 20%"
    @State private var countWords = "count · 3"

    /// The stepper's value, declared the same way. Its caption matters more
    /// than the slider's: on some platforms a Stepper draws two buttons and
    /// no number, and there the caption above it is what shows the value.
    @State private var count = 3.0
    // listing: end

    static let id = "animatedInput"
    static let title = "Animated inputs"
    static let summary = "Two sliders over identical states - one also read by the page, one only handed on with `$`."

    // listing: AnimatedInputSample
    var body: some View {
        // Each part is a closure of its own and takes its own build reading,
        // which is what tells them apart.
        VStack {
            VStack {
                Text("A get")
                    .fontSize(12)
                    .textColor(Palette.subtle)

                // A GET. The label below prints `volume`, which makes THIS
                // closure a reader of it - so every report the thumb makes
                // builds it.
                DebugInfoLabel()

                Text("volume · \(percent(volume))")
                    .fontSize(15)

                Slider($volume)
                    .accessibilityIdentifier("animatedInput.volume")
                    .accessibilityLabel("Volume")
                    .minimum(0)
                    .maximum(1)
                    .tint(Palette.subtle)

                button("Send the top one") {
                    // An assignment sends the thumb there under the element's
                    // law, and costs the one render this line asks for.
                    volume = volume < 0.5 ? 1 : 0
                }
            }
            .spacing(10)

            VStack {
                Text("A binding")
                    .fontSize(12)
                    .textColor(Palette.subtle)

                DebugInfoLabel()

                // WORDS AN ENGINE WRITES: it follows the journey, so it runs on
                // the display's frames as the thumb moves - under the hand or
                // sent - reads where the value has got to, and the words keep
                // up with the movement and cost no render.
                Text($levelWords)
                    .fontSize(15)
                    .textColor(Palette.accent)
                    .engine(following: $level.journey) { _ in
                        guard let sample = $level.journey.sample else { return }
                        levelWords = "level · \(Int((sample.value * 100).rounded()))%"
                    }

                // THE SAME DECLARATION as above, and the same spelling: what
                // differs is that nothing here reads `level` at build.
                Slider($level)
                    .accessibilityIdentifier("animatedInput.level")
                    .accessibilityLabel("Level")
                    .minimum(0)
                    .maximum(1)
                    .tint(Palette.accent)

                button("Send the bottom one") {
                    try await $level.journey.move(to: level < 0.5 ? 1 : 0,
                                               .eased(.milliseconds(900), curve: .cubicInOut)).result()
                }
            }
            .spacing(10)

            VStack {
                DebugInfoLabel()

                Text($countWords)
                    .fontSize(15)
                    .textColor(Palette.accent)
                    .engine(following: $count.journey) { _ in
                        guard let sample = $count.journey.sample else { return }
                        countWords = "count · \(Int(sample.value.rounded()))"
                    }

                Stepper($count)
                    .accessibilityIdentifier("animatedInput.count")
                    .accessibilityLabel("Count")
                    .minimum(0)
                    .maximum(20)
                    .step(1)
                    .horizontalAlignment(.start)

                button("Send the stepper to 12") {
                    try await $count.journey.move(to: 12, .eased(.milliseconds(800))).result()
                }
            }
            .spacing(10)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The build count each half takes is what tells them apart. The top "
                + "caption PRINTS `volume`, which makes the closure it sits in a "
                + "reader, so every report the thumb makes builds that closure again, "
                + "and nothing around it. `level` is handed on as `$level` - to the "
                + "slider, and as `$level.journey` to the caption's engine - and a binding "
                + "makes no reader: a drag and a journey leave the count where it was.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("THAT IS THE WHOLE RULE. A value read in a body - a get - makes the "
                + "body a reader, and a write to the state renders it. A value handed "
                + "on as `$x` - to a control, a modifier, a child or an engine - makes "
                + "no reader, and the host carries it with nothing rebuilt. Where a "
                + "body must show a value that moves, it reads it and pays a render "
                + "per report, or `.samples($x.journey, into:, .every(.milliseconds(100)))` holds a "
                + "reading to ten a second; where it need not, words an engine writes show it "
                + "for nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("AND A READING THAT MUST KEEP UP READS THE JOURNEY. Every walked "
                + "state has one: `level` is where it is GOING, from the first "
                + "millisecond; `$level.journey.sample` where it HAS GOT TO this frame - "
                + "so a caption written from the sample counts its way along it "
                + "where one converted from the state itself would jump to the "
                + "destination at once. The journey is also what steers the value: "
                + "`move(to:)`, `stop()`, `snap(to:)`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Both captions are written by an ENGINE FOLLOWING THE JOURNEY - "
                + "`.engine(following: $level.journey) { … }` - which runs on the "
                + "display's own frames whenever where the host shows the value has "
                + "changed, so a drag and a journey both cost the arithmetic and no "
                + "renders. The stepper needs its caption more than "
                + "the slider does: on some platforms a Stepper draws two buttons and "
                + "no number, and there the caption is what shows the value.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    // listing: AnimatedInputSample
    /// Whole percent, written by hand - a formatter is Foundation.
    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .onClicked(policy: .cancelPrevious, act)
    }
    // listing: end
}
