import StateUI

/// MAUI: Slider.Value and Stepper.Value - the two properties a READER can move
/// and the host can carry, side by side in both spellings so the difference
/// between them is on the screen.
struct AnimatedInputSample: SampleContent {
    /// The TOP slider's value, described: `Slider($volume)` shows it and writes
    /// every drag report back into it, so every one of those reports is a
    /// render of this whole page.
    @State private var volume = 0.2

    /// The BOTTOM slider's value, DRIVEN: the host reads the thumb off this
    /// state on its own frames and writes a drag back into it, and no render
    /// happens either way.
    @Bus private var level = AnimatedValue(0.2)

    /// What the bottom slider reads, worked out by an engine following `level`.
    /// A driven text, so showing it costs no render either.
    @Bus private var reading = "20%"

    /// The stepper's value, driven the same way.
    @Bus private var count = AnimatedValue(3.0)

    /// What the stepper reads. A Stepper draws its two buttons and NO number,
    /// so without this the reader cannot see what it is on - and a view cannot
    /// SHOW a driven state, nothing telling the tree it moved. So the number is
    /// a driven text, written by the same engine.
    @Bus private var counted = "count · 3"

    static let id = "animatedInput"
    static let title = "Animated inputs"
    static let summary = "A slider and a stepper carried to a value - described "
        + "in one spelling, driven in the other."

    static let code = """
        // Described: every drag report writes the state and renders the page.
        @State private var volume = 0.2

        // Driven: the host reads the thumb off this state and writes a drag
        // back into it, and neither costs a render.
        @Bus private var level = AnimatedValue(0.2)
        @Bus private var reading = "20%"
        @Bus private var count = AnimatedValue(3.0)

        // A Stepper draws two buttons and NO number, and a view cannot show a
        // driven state - so its reading is a driven text too.
        @Bus private var counted = "count · 3"

        // The count in the corner is the instrument the two spellings are told
        // apart by. Every example in this gallery wears one.
        VStack {
            // DESCRIBED. Drag it and the count in the corner climbs, once per
            // report.
            Label("volume · \\(percent(volume))")

            Slider($volume)
                .minimum(0)
                .maximum(1)

            Button("Send the described one").onClicked {
                // An assignment travels under the ELEMENT's own motion.
                volume = volume < 0.5 ? 1 : 0
            }

            // DRIVEN. Drag it, or send it, and the count does not move at all.
            Label().text($reading)

            // THE SAME SPELLING as the described one above. What makes this
            // the driven slider is the DECLARATION of `level`, and nothing here.
            Slider($level)
                .minimum(0)
                .maximum(1)

            Button("Send the driven one").onClicked {
                try await $level.animateTo(
                    level.setPoint < 0.5 ? 1 : 0, .eased(900, .cubicInOut))
            }

            // A VALUE written is a snap, and it ends any movement under way.
            Button("Snap the driven one to half").onClicked { level.value = 0.5 }

            Label().text($counted)

            Stepper($count)
                .minimum(0)
                .maximum(20)
                .increment(1)

            Button("Send the stepper to 12").onClicked {
                try await $count.animateTo(12, .eased(800, .cubicOut))
            }
        }
        // Every frame of both movements, and every report either control makes,
        // with no render anywhere. ONE engine for the two of them: it runs when
        // either state moves, and a text written unchanged crosses as nothing.
        .engine(following: $level, $count) { _ in
            reading = "level · \\(Int((level.value * 100).rounded()))%"
            counted = "count · \\(Int(count.value.rounded()))"
        }

        /// Whole percent, written by hand - a formatter is Foundation.
        func percent(_ value: Double) -> String {
            "\\(Int((value * 100).rounded()))%"
        }
        """

    var example: Element {
        // The instrument the two spellings are told apart by is the build count
        // in the corner, which every example in this gallery wears.
        VStack {
            Label("DESCRIBED — drag it and the count in the corner climbs")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("volume · \(percent(volume))")
                .fontSize(15)

            Slider($volume)
                .minimum(0)
                .maximum(1)
                .minimumTrackColor(Palette.subtle)

            button("Send the described one") {
                volume = volume < 0.5 ? 1 : 0
            }

            Label("DRIVEN — drag it, or send it, and the count stands still")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label()
                .text($reading)
                .fontSize(15)
                .textColor(Palette.accent)

            // THE SAME SPELLING as the described one above: what makes this the
            // driven slider is where `level` was declared, and nothing here.
            Slider($level)
                .minimum(0)
                .maximum(1)
                .minimumTrackColor(Palette.accent)

            HStack {
                button("Send the driven one") {
                    try await $level.animateTo(
                        level.setPoint < 0.5 ? 1 : 0, .eased(900, .cubicInOut))
                }

                button("Snap to half") { level.value = 0.5 }
            }
            .spacing(8)
            .horizontalOptions(.center)

            Label()
                .text($counted)
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
        .engine(following: $level, $count) { _ in
            reading = "level · \(Int((level.value * 100).rounded()))%"
            counted = "count · \(Int(count.value.rounded()))"
        }
    }

    var notes: Element? {
        VStack {
            Label("Two sliders, one described and one driven, and the build count in "
                + "the corner is what tells them apart. Drag the top one and it climbs "
                + "once per report the platform makes; drag the bottom one and it does "
                + "not move at all, though the reading under it follows the thumb. The "
                + "stepper's number is the same answer: a Stepper draws no number of "
                + "its own, and a view cannot show a driven state - so an engine writes "
                + "it as text.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("BOTH ARE WRITTEN `Slider($x)`. What tells them apart is the "
                + "DECLARATION: `@State var volume = 0.2` is a value the tree shows, "
                + "so every drag report is a render; `@Bus var "
                + "level = AnimatedValue(0.2)` is a value the HOST carries, so it "
                + "registers once and nothing mentions it again. The call site never "
                + "says which, and never has to.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("What tells a drag from the host's own frames is WHEN the platform "
                + "reports: inside the host's write it is the host hearing itself and "
                + "is dropped, outside it the number is the reader's and is written "
                + "back. A thumb already moving is the platform's to give up, though, "
                + "and on Mac Catalyst it does not - send the driven slider across and "
                + "grab it half way, and it goes on to where it was sent.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Both readings are driven TEXTS, written by one engine following the "
                + "two states. It runs on the display's own frames, so a 900ms journey "
                + "and a drag both cost the arithmetic and no renders. Snap to half "
                + "writes `level.value`, which is the one write that does not travel - "
                + "and it ends whatever was carrying the thumb.")
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
