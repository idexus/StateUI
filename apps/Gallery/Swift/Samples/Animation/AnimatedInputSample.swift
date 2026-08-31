import StateUI

/// MAUI: Slider.Value and Stepper.Value - the two properties a READER can move
/// and a flight can walk, which is why the binding each of them borrows is
/// armed like a property written from state.
struct AnimatedInputSample: SampleContent {
    /// Where the slider is set. `Slider($volume)` shows it, writes a drag back
    /// into it, and ARMS it - so the same state a finger moves can be flown.
    @State private var volume = 0.2

    /// What the thumb is passing through while it walks. A SECOND state,
    /// because the flying one stands at its target from the first line; never
    /// the flying state itself, an assignment to which ends the walk.
    @State private var showing = 0.2

    /// The stepper's value, armed the same way by `Stepper($count)`.
    @State private var count = 3.0

    /// How many times the platform has raised ValueChanged. It raises one for
    /// every step of its OWN walk as well as for a drag, which is the measured
    /// reason the binding ignores a report while it flies.
    @State private var reports = 0

    static let id = "animatedInput"
    static let title = "Animated inputs"
    static let summary = "A slider and a stepper flown to a value - the two "
        + "controls whose binding is armed."

    static let code = """
        @State private var volume = 0.2
        @State private var showing = 0.2
        @State private var count = 3.0

        // Climbs during a flight too: the platform reports every value it
        // passes through.
        @State private var reports = 0

        VStack {
            // The state stands at the TARGET the whole way; `showing` is what
            // the thumb is actually passing through.
            Label("volume · \\(percent(volume))")
            Label("thumb · \\(percent(showing))")

            // Two-way AND armed: a drag writes back, a flight walks it.
            Slider($volume)
                .minimum(0)
                .maximum(1)
                .onValueChanged { _ in reports += 1 }

            Label("the platform has raised ValueChanged \\(reports)x")

            Button("Fade out").onClicked {
                try await $volume.animateTo(0, .eased(900, .cubicInOut),
                                            reporting: $showing)
            }

            Button("Full").onClicked {
                try await $volume.animateTo(1, .eased(900, .cubicInOut),
                                            reporting: $showing)
            }

            // Assigning SNAPS, and ends any walk on that property.
            Button("Snap to half").onClicked {
                volume = 0.5
                showing = 0.5
            }

            Stepper($count)
                .minimum(0)
                .maximum(20)
                .increment(1)

            Button("Walk to 12").onClicked {
                try await $count.animateTo(12, .eased(800, .cubicOut))
            }
        }

        /// Whole percent, written by hand - a formatter is Foundation.
        func percent(_ value: Double) -> String {
            "\\(Int((value * 100).rounded()))%"
        }
        """

    var content: Element {
        VStack {
            HStack {
                Label("volume · \(percent(volume))")
                    .fontSize(15)
                    .horizontalOptions(.start)

                Label("thumb · \(percent(showing))")
                    .fontSize(15)
                    .textColor(Palette.accent)
                    .horizontalOptions(.end)
                    .horizontalTextAlignment(.end)
            }
            .spacing(12)

            Slider($volume)
                .minimum(0)
                .maximum(1)
                .minimumTrackColor(Palette.accent)
                .onValueChanged { _ in reports += 1 }

            Label("the platform has raised ValueChanged \(reports)x")
                .fontSize(12)
                .textColor(Palette.subtle)

            HStack {
                button("Fade out") {
                    try await $volume.animateTo(0, .eased(900, .cubicInOut),
                                                reporting: $showing)
                }

                button("Full") {
                    try await $volume.animateTo(1, .eased(900, .cubicInOut),
                                                reporting: $showing)
                }

                button("Snap to half") {
                    volume = 0.5
                    showing = 0.5
                }
            }
            .spacing(8)
            .horizontalOptions(.center)

            Label("count · \(Int(count))")
                .fontSize(15)

            Stepper($count)
                .minimum(0)
                .maximum(20)
                .increment(1)
                .horizontalOptions(.start)

            button("Walk to 12") {
                try await $count.animateTo(12, .eased(800, .cubicOut))
            }
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("A two-way input ARMS the value it borrows. `Slider($volume)` already "
                + "showed the state and wrote a drag back into it; arming is the third "
                + "thing it does, and it is what lets the thumb be FLOWN to a value the "
                + "reader could have dragged it to. `Stepper($count)` is the same, and "
                + "they are the only two - the rest of what can fly is a property "
                + "written from state, which the Animated properties sample shows.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Watch the two readings during a flight. `volume` is at the target "
                + "from the first line - that is the model, so a render mid-walk "
                + "describes where the value is GOING and says nothing new - while "
                + "`thumb` sweeps, because `reporting: $showing` asks for a reading "
                + "every 100ms of the walk's own clock. Never report into the flying "
                + "state: that is an assignment to an armed property, which is exactly "
                + "what Snap to half does on purpose.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The counter climbs during a flight with nothing touching the "
                + "slider: the platform reports every value it passes through, and your "
                + "own `.onValueChanged` hears them all. The binding is not written by "
                + "them, so the flight runs to its target either way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Drag the thumb after a flight and it still writes back - arming "
                + "takes nothing away. A drag DURING one is ignored with the "
                + "platform's own reports, the flight being the thing that was asked "
                + "for last.")
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
