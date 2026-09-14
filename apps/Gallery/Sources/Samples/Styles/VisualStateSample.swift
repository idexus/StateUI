import StateUI

/// States written on the control itself, and the list of them being the
/// control's own.
struct VisualStateSample: SampleContent, ExampleContent {
    @State private var enabled = true
    @State private var presses = 0
    @State private var ready = true
    @State private var busy = false
    @State private var entered = "Normal"

    /// How big the button is drawn, and what the state handler moves. DRIVEN:
    /// the button's scale is read off this state on the host's own frames, so
    /// the handler has nothing to aim at and no render carries the movement.
    @State private var press = 1.0

    static let id = "visual-states"
    static let title = "Visual states"
    static let summary = "What a control looks like while it is held down, disabled or chosen."

    static let code = """
        @State private var enabled = true
        @State private var presses = 0
        @State private var ready = true
        @State private var busy = false
        @State private var entered = "Normal"
        @State private var press = 1.0

        VStack {
            // A visual state is worn by the host and renders nobody. What
            // DOES render here is `entered`, written by the handler and read
            // in this closure - so the count follows the reports, not the look.
            DebugInfoLabel()

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
                .motion(.none)
                .visualState(.pressed) { $0.background(Palette.brand) }
                .onClicked { presses += 1 }

            Switch($enabled)

            Label("entered \\(entered) · pressed \\(presses) times")

            // A RadioButton has two states of its own, and it RESTS in
            // .unchecked rather than .normal.
            RadioButton("Ready")
                .isChecked($ready)
                .visualState(.checked) { $0.background(Palette.selected) }

            RadioButton("Busy")
                .isChecked($busy)
                .visualState(.checked) { $0.background(Palette.selected) }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            SectionTitle("On the control, not in a style")

            // TWO OF THEM, SIDE BY SIDE, because the difference is the point:
            // hold each one down and the left crosses to its pressed colour
            // while the right arrives at it.
            HStack {
                Button(enabled ? "Hold me" : "Disabled")
                    .isEnabled(enabled)
                    .scale($press)
                    .visualState(.pressed) { $0.background(Palette.brand) }
                    .visualState(.disabled) { $0
                        .background(Palette.outline)
                        .textColor(Palette.disabled)
                    }
                    .onVisualStateChanged { state in
                        entered = state.name
                        try await $press.journey.move(to: state == .pressed ? 0.94 : 1, .eased(90))
                    }
                    .onClicked { presses += 1 }

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
                Label("Enabled")
                    .fontSize(14)
                    .verticalAlignment(.center)

                Switch($enabled)
                    .automationId("visual-states.enabled")
                    .semanticDescription("Enabled")
            }
            .spacing(12)
            .horizontalAlignment(.center)

            Label("entered \(entered) · pressed \(presses) times")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            SectionTitle("States only a RadioButton has")

            RadioButton("Ready")
                .isChecked($ready)
                .visualState(.checked) { $0.background(Palette.selected) }

            RadioButton("Busy")
                .isChecked($busy)
                .visualState(.checked) { $0.background(Palette.selected) }
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Which states a control enters is the control's own business, so the "
                + "list after the dot is exactly those. A Button has .pressed, a Switch has "
                + ".on and .off, a CheckBox has .isChecked, a RadioButton has .checked and "
                + ".unchecked - and every view has .normal, .disabled, .focused, "
                + ".unfocused, .pointerOver and .selected. Writing a state a control never "
                + "enters does not compile: it would be a style that silently does nothing. "
                + "And .pointerOver is a desktop's: nothing on a touch-only device enters it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The colour is a SETTER, and it CROSSES: a visual state is carried by "
                + "the engine at the control's own motion. `Hold me too` wears "
                + "`.motion(.none)`, so held side by side the first crosses to its pressed "
                + "colour while the second arrives at it. The size takes 90ms and is "
                + "awaited, which is the reason to hear a state rather than only set it. "
                + "What moves is `press`, a DRIVEN state the button's scale is read off - "
                + "so the whole 90ms costs no render, and the state stands at 0.94 from "
                + "the first millisecond while the button is still on its way there.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A control reports the states it DECLARES and nothing else. Naming "
                + "states in .onVisualStateChanged declares them without changing how they "
                + "look; the first button writes both already. The gallery's "
                + "`Style<Button>` also says what a disabled button looks like, and the two "
                + "are MERGED: the control's setters are written over the style's, one "
                + "property at a time.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A resting state need not be written: a group that names none is given "
                + "an empty one, so a control that enters .disabled comes back to its own "
                + "look when it is enabled again. That resting state is .normal for every "
                + "control but a RadioButton, which RESTS in .unchecked.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
