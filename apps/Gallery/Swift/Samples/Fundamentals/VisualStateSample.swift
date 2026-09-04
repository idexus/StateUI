import StateUI

/// States written on the control itself, and the list of them being the
/// control's own.
struct VisualStateSample: SampleContent {
    @State private var enabled = true
    @State private var presses = 0
    @State private var ready = true
    @State private var busy = false
    @State private var entered = "Normal"

    /// How big the button is drawn, and what the state handler moves. DRIVEN:
    /// the button's scale is read off this state on the host's own frames, so
    /// the handler has nothing to aim at and no render carries the movement.
    @State(describing: .none) private var press = AnimatedValue(1.0)

    static let id = "visual-states"
    static let title = "Visual states"
    static let summary = "What a control looks like while it is held down, disabled or chosen."

    static let code = """
        @State private var enabled = true
        @State private var presses = 0
        @State private var ready = true
        @State private var busy = false
        @State private var entered = "Normal"
        @State(describing: .none) private var press = AnimatedValue(1.0)

        VStack {
            // Written on the CONTROL rather than in a style. The states after
            // the dot are the ones a Button actually enters: .pressed is there,
            // and .on - which is a Switch's - does not compile.
            Button(enabled ? "Hold me" : "Disabled")
                .isEnabled(enabled)
                .scale($press)
                .visualState(.pressed) { $0.backgroundColor(Palette.brand) }
                .visualState(.disabled) { $0
                    .backgroundColor(Palette.outline)
                    .textColor(Palette.disabled)
                }
                // The colour is a setter and the engine carries it at the
                // button's own motion; this takes 90ms, because a handler may
                // await. The scale is DRIVEN by `press`, so the handler sends
                // the state and the button follows it.
                .onVisualStateChanged { state in
                    entered = state.name
                    try await $press.animateTo(state == .pressed ? 0.94 : 1, .eased(90))
                }
                .onClicked { presses += 1 }

            // THE SAME STATES, ARRIVING, so the two can be held down side by
            // side: a visual state travels under the control's own motion, and
            // `.motion(.none)` is what none of it looks like.
            Button(enabled ? "Hold me too" : "Disabled")
                .isEnabled(enabled)
                .motion(.none)
                .visualState(.pressed) { $0.backgroundColor(Palette.brand) }
                .onClicked { presses += 1 }

            Switch($enabled)

            // A RadioButton has two states of its own, and it RESTS in
            // Unchecked rather than Normal - MAUI enters its own pair before
            // the ordinary Normal, so a Normal beside them would end every
            // transition and neither would ever be seen.
            RadioButton("Ready")
                .isChecked($ready)
                .visualState(.checked) { $0.backgroundColor(Palette.selected) }

            RadioButton("Busy")
                .isChecked($busy)
                .visualState(.checked) { $0.backgroundColor(Palette.selected) }
        }
        """

    var content: Element {
        VStack {
            Label("Which states a control enters is the control's own business, so the list "
                + "after the dot is exactly those. A Button has .pressed, a Switch has .on and "
                + ".off, a CheckBox has .isChecked, a RadioButton has .checked and .unchecked - "
                + "and every view has .normal, .disabled, .focused, .unfocused, .pointerOver "
                + "and .selected. Writing a state a control never enters does not compile, "
                + "which is the point: it would have been a style that silently did nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("ON THE CONTROL, NOT IN A STYLE")

            // TWO OF THEM, SIDE BY SIDE, because the difference is the point:
            // hold each one down and the left crosses to its pressed colour
            // while the right arrives at it.
            HStack {
                Button(enabled ? "Hold me" : "Disabled")
                    .isEnabled(enabled)
                    .scale($press)
                    .visualState(.pressed) { $0.backgroundColor(Palette.brand) }
                    .visualState(.disabled) { $0
                        .backgroundColor(Palette.outline)
                        .textColor(Palette.disabled)
                    }
                    .onVisualStateChanged { state in
                        entered = state.name
                        try await $press.animateTo(state == .pressed ? 0.94 : 1, .eased(90))
                    }
                    .onClicked { presses += 1 }

                Button(enabled ? "Hold me too" : "Disabled")
                    .isEnabled(enabled)
                    // THE SAME STATES, ARRIVING. A visual state travels under
                    // the control's own motion, and this is what none looks
                    // like.
                    .motion(.none)
                    .visualState(.pressed) { $0.backgroundColor(Palette.brand) }
                    .visualState(.disabled) { $0
                        .backgroundColor(Palette.outline)
                        .textColor(Palette.disabled)
                    }
                    .onClicked { presses += 1 }
            }
            .spacing(12)
            .horizontalOptions(.center)

            HStack {
                Label("Enabled")
                    .fontSize(14)
                    .verticalOptions(.center)

                Switch($enabled)
            }
            .spacing(12)
            .horizontalOptions(.center)

            Label("entered \(entered) · pressed \(presses) times")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Label("The colour is a SETTER, and it CROSSES: a visual state is carried by "
                + "the engine at the control's own motion. The size takes 90ms and is "
                + "awaited, which is the reason to hear a state rather than only set it. "
                + "What moves is `press`, a DRIVEN state the button's scale is read off - "
                + "so the whole 90ms costs no render, and the state stands at 0.94 from "
                + "the first millisecond while the button is still on its way there.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A control reports the states it DECLARES and nothing else. Naming "
                + "states in .onVisualStateChanged(...) declares them without changing "
                + "how they look; this button had written both already.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The gallery's Style<Button> already says what a disabled button looks "
                + "like. This one says it for itself, and the two are MERGED: the control's "
                + "setters are written over the style's, one property at a time, the rule "
                + "every other value here follows.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("STATES ONLY A RADIOBUTTON HAS")

            RadioButton("Ready")
                .isChecked($ready)
                .visualState(.checked) { $0.backgroundColor(Palette.selected) }

            RadioButton("Busy")
                .isChecked($busy)
                .visualState(.checked) { $0.backgroundColor(Palette.selected) }
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("A RadioButton RESTS in Unchecked rather than Normal, and that is MAUI's "
                + "doing: RadioButton.ChangeVisualState enters Checked or Unchecked first and "
                + "the ordinary Normal after it, so a Normal declared beside the pair would "
                + "end every transition and neither state would ever be seen. So the state a "
                + "group is given when it named none is the TARGET's, not always Normal.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The wash is the state; the CAPTION is deliberately not. A RadioButton's "
                + "textColor does not reach its caption on Mac Catalyst - measured, with a "
                + "plain red assigned straight to the control - so a state that coloured the "
                + "words would be a state that did nothing there. Its backgroundColor does.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A group is left by entering another state, so one with no way back is a "
                + "trap: a control that enters Disabled once and has no resting state stays "
                + "drawn that way for the rest of its life. That is why a resting state is "
                + "put in front of any group that did not write one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("And .pointerOver is a desktop's: nothing on a touch-only device ever "
                + "enters it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
