import StateUI

/// States written on the control itself, and the list of them being the
/// control's own.
struct VisualStateSample: SampleContent, ExampleContent {
    // listing: VisualStateSample
    @State private var enabled = true
    @State private var presses = 0
    @State private var ready = true
    @State private var busy = false
    @State private var entered = "Normal"

    /// How big the button is drawn, and what the state handler moves. DRIVEN:
    /// the button's scale is read off this state on the host's own frames, so
    /// the handler has nothing to aim at and no render carries the movement.
    @State private var press = 1.0
    // listing: end

    static let id = "visual-states"
    static let title = "Visual states"
    static let summary = "What a control looks like while it is held down, disabled or chosen."

    // listing: VisualStateSample
    var body: some View {
        VStack {
            // A state describes the button alone. What renders this closure is
            // `entered`, written by the handler and read here - so the count
            // follows what was heard, not the look.
            DebugInfoLabel()

            SectionTitle("On the control, not in a style")

            // TWO OF THEM, SIDE BY SIDE, because the difference is the point:
            // hold each one down and the left crosses to its pressed colour
            // while the right arrives at it.
            HStack {
                // Written on the CONTROL rather than in a style. The states after
                // the dot are the ones a Button actually enters: .pressed is there,
                // and .on - which is a Switch's - does not compile.
                Button(enabled ? "Hold me" : "Disabled")
                    .isEnabled(enabled)
                    .scale($press)
                    .visualState(.pressed) { $0.background(Palette.brand) }
                    .visualState(.disabled) { $0
                        .background(Palette.outline)
                        .textColor(Palette.disabled)
                    }
                    // The colour is a setter and the engine carries it at the
                    // button's own motion; this takes 90ms, because a handler may
                    // await. The scale is DRIVEN by `press`, so the handler sends
                    // the state and the button follows it.
                    .onVisualStateChanged { state in
                        entered = state.name
                        try await $press.journey.move(to: state == .pressed ? 0.94 : 1, .eased(90))
                    }
                    .onClicked { presses += 1 }

                // THE SAME STATES, ARRIVING, so the two can be held down side by
                // side: a visual state travels under the control's own motion, and
                // `.motion(.none)` is what none of it looks like.
                Button(enabled ? "Hold me too" : "Disabled")
                    .isEnabled(enabled)
                    // THE SAME STATES, ARRIVING. A visual state travels under
                    // the control's own motion, and this is what none looks
                    // like.
                    .motion(.none)
                    .visualState(.pressed) { $0.background(Palette.brand) }
                    .visualState(.disabled) { $0
                        .background(Palette.outline)
                        .textColor(Palette.disabled)
                    }
                    .onClicked { presses += 1 }
            }
            .spacing(12)
            .horizontalAlignment(.center)

            HStack {
                Text("Enabled")
                    .fontSize(14)
                    .verticalAlignment(.center)

                Switch($enabled)
                    .accessibilityIdentifier("visual-states.enabled")
                    .accessibilityLabel("Enabled")
            }
            .spacing(12)
            .horizontalAlignment(.center)

            Text("entered \(entered) · pressed \(presses) times")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            SectionTitle("States only a RadioButton has")

            // A RadioButton has two states of its own, following isOn.
            RadioButton("Ready")
                .isOn($ready)
                .visualState(.checked) { $0.background(Palette.selected) }

            RadioButton("Busy")
                .isOn($busy)
                .visualState(.checked) { $0.background(Palette.selected) }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Hold each button down: the left crosses to its pressed colour, the right arrives at it. "
            + "Turn Enabled off for the disabled look, and choose a radio button for the checked one.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
