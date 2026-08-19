import StateUI

/// MAUI: VisualElement.Opacity, TranslationX, Scale and Rotation, flown.
struct AnimationSample: SampleContent {
    @State private var curve = 0

    /// The four values the card is drawn from, one per thing a button moves.
    ///
    /// Each is ARMED on the Border below - the property is written from its
    /// BINDING rather than from a value - and that is the whole of what makes
    /// it something a flight can walk. A Border that names none of them has
    /// nothing to move.
    @State private var fade = 1.0
    @State private var shift = 0.0
    @State private var scale = 1.0
    @State private var angle = 0.0

    static let id = "animation"
    static let title = "Animations"
    static let summary = "Fade, move, scale and spin a view by flying the state behind it."

    static let curves = ["Linear", "Cubic in-out", "Bounce out", "Spring out"]

    static let code = """
        @State private var curve = 0

        @State private var fade = 1.0
        @State private var shift = 0.0
        @State private var scale = 1.0
        @State private var angle = 0.0

        static let curves = ["Linear", "Cubic in-out", "Bounce out", "Spring out"]

        VStack {
            Border {
                Label("Animate me")
            }
            // Four armed properties. Written from a binding, so each of them
            // is a value the tree describes AND a value a flight can walk.
            .opacity($fade)
            .translationX($shift)
            .scale($scale)
            .rotation($angle)
            .backgroundColor(Palette.accent)

            Picker(Self.curves)
                .selectedIndex($curve)
                .title("Easing")

            HStack {
                // A flight answers whether it ran to the END. Stop says false,
                // and so does a second press taking this one's place - and the
                // way back is not flown over whatever happened instead.
                Button("Fade").onClicked {
                    let landed = try await $fade.animateTo(0.1, length: 400, easing: easing)
                    if landed { try await $fade.animateTo(1, length: 400, easing: easing) }
                }

                // ONE flight, because the card only ever moves sideways. A
                // diagonal would be a second state on translationY, started
                // with `async let` so the two land together.
                Button("Move").onClicked {
                    let landed = try await $shift.animateTo(60, length: 400, easing: easing)
                    if landed { try await $shift.animateTo(0, length: 400, easing: easing) }
                }

                Button("Scale").onClicked {
                    let landed = try await $scale.animateTo(1.4, length: 400, easing: easing)
                    if landed { try await $scale.animateTo(1, length: 400, easing: easing) }
                }

                // A flight walks TO a value, never BY one, so a full turn is
                // the author's arithmetic. The state keeps the angle the card
                // came to rest at, which is what makes the next press carry
                // on from there rather than start over.
                Button("Spin").onClicked {
                    angle += 360
                    try await $angle.animateTo(angle, length: 700, easing: easing)
                }
            }

            // Whichever of them is in the air; a state with nothing flying
            // answers nothing. Each stop writes back what the control had
            // actually reached, so the card stays where the reader saw it
            // stop and the tree says the same thing.
            Button("Stop").onClicked {
                try await $fade.stop()
                try await $shift.stop()
                try await $scale.stop()
                try await $angle.stop()
            }
        }

        /// The curve the picker is on. MAUI's names, camelCased.
        private var easing: Easing {
            switch curve {
            case 1: return .cubicInOut
            case 2: return .bounceOut
            case 3: return .springOut
            default: return .linear
            }
        }
        """

    var content: Element {
        VStack {
            Border {
                Label("Animate me")
                    .fontSize(17)
                    .textColor(Palette.onAccent)
                    .padding(24, 16)
            }
            // Four armed properties. Written from a binding, so each of them is
            // a value the tree describes AND a value a flight can walk.
            .opacity($fade)
            .translationX($shift)
            .scale($scale)
            .rotation($angle)
            .backgroundColor(Palette.accent)
            .stroke(.transparent)
            .strokeShape(.roundRectangle(12))
            .horizontalOptions(.center)

            Picker(Self.curves)
                .selectedIndex($curve)
                .title("Easing")

            HStack {
                // A flight answers whether it ran to the END. Stop says false,
                // and so does a second press taking this one's place - and the
                // way back is not flown over whatever happened instead, which
                // is what lets Stop leave the card where it stood.
                button("Fade") {
                    let landed = try await $fade.animateTo(0.1, length: 400, easing: easing)
                    if landed { try await $fade.animateTo(1, length: 400, easing: easing) }
                }

                // ONE flight, because the card only ever moves sideways. A
                // diagonal would be a second state on translationY, started
                // with `async let` so the two land together.
                button("Move") {
                    let landed = try await $shift.animateTo(60, length: 400, easing: easing)
                    if landed { try await $shift.animateTo(0, length: 400, easing: easing) }
                }

                button("Scale") {
                    let landed = try await $scale.animateTo(1.4, length: 400, easing: easing)
                    if landed { try await $scale.animateTo(1, length: 400, easing: easing) }
                }

                // A flight walks TO a value, never BY one, so a full turn is the
                // author's arithmetic. The state keeps the angle the card came
                // to rest at, which is what makes the next press carry on from
                // there rather than start over.
                button("Spin") {
                    angle += 360
                    try await $angle.animateTo(angle, length: 700, easing: easing)
                }
            }
            .spacing(8)
            .horizontalOptions(.center)

            // Whichever of them is in the air; a state with nothing flying
            // answers nothing. Each stop writes back what the control had
            // actually reached, so the card stays where the reader saw it stop
            // and the tree says the same thing.
            button("Stop") {
                try await $fade.stop()
                try await $shift.stop()
                try await $scale.stop()
                try await $angle.stop()
            }
            .horizontalOptions(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Each button moves STATE. `.opacity($fade)` ARMS the property "
                + "with the state behind it, and `$fade.animateTo(0.1, …)` walks "
                + "everything armed with `fade` to 0.1. `await` says the walk is "
                + "over and the answer says whether it reached the end, which is "
                + "what lets one flight follow another without a callback.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The state is given the TARGET at once - reading `fade` on the "
                + "line after answers 0.1, not what is on the screen - and what "
                + "glides is the control. So the tree always describes where a "
                + "walk ENDS, a rebuild in the middle of one says nothing about "
                + "it, and `fade = 0.5` instead of a flight simply snaps.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("There is no relative turn and no two-axis move. Spin adds 360 "
                + "to the angle and flies to the sum, so each press carries on "
                + "from the last; Move is a single flight on translationX, the "
                + "only axis this card uses.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Move comes back because the sample says so, not because it "
                + "must: the translation is described now, so a card left at 60 "
                + "stays at 60 through any rebuild. Stop is the other half of "
                + "that - it writes back what the control had reached, so a walk "
                + "broken off halfway leaves the tree and the screen agreeing.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(14, 6)
            .onClicked(act)
    }

    /// The curve the picker is on. MAUI's names, camelCased.
    private var easing: Easing {
        switch curve {
        case 1: return .cubicInOut
        case 2: return .bounceOut
        case 3: return .springOut
        default: return .linear
        }
    }
}
