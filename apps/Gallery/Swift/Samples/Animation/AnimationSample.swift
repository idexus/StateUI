import StateUI

/// MAUI: VisualElement.Opacity, TranslationX, Scale and Rotation, driven.
struct AnimationSample: SampleContent {
    @State private var curve = 0

    /// The four values the card is drawn from, one per thing a button moves.
    ///
    /// Each is DRIVEN on the Border below - the property is read off the state
    /// on the host's own frames rather than described - so a four-hundred
    /// millisecond journey costs no renders at all. A Border that names none
    /// of them has nothing to move.
    @Bus private var fade = AnimatedValue(1.0)
    @Bus private var shift = AnimatedValue(0.0)
    @Bus private var scale = AnimatedValue(1.0)
    @Bus private var angle = AnimatedValue(0.0)

    static let id = "animation"
    static let title = "Animations"
    static let summary = "Fade, move, scale and spin a view by sending the driven state behind it."

    static let curves = ["Linear", "Cubic in-out", "Bounce out", "Spring out"]

    static let code = """
        @State private var curve = 0

        @Bus private var fade = AnimatedValue(1.0)
        @Bus private var shift = AnimatedValue(0.0)
        @Bus private var scale = AnimatedValue(1.0)
        @Bus private var angle = AnimatedValue(0.0)

        static let curves = ["Linear", "Cubic in-out", "Bounce out", "Spring out"]

        VStack {
            Border {
                Label("Animate me")
            }
            // Four DRIVEN properties. Read off a state the host moves, so none
            // of them is on any message after the registration.
            .opacity($fade)
            .translationX($shift)
            .scale($scale)
            .rotation($angle)
            .backgroundColor(Palette.accent)

            Picker(Self.curves)
                .selectedIndex($curve)
                .title("Easing")

            HStack {
                // A movement answers whether it ran to the END. Stop says
                // false, and so does a second press taking this one's place -
                // and the way back is not taken over whatever happened instead.
                Button("Fade").onClicked {
                    let landed = try await $fade.animateTo(0.1, .eased(400, easing))
                    if landed { try await $fade.animateTo(1, .eased(400, easing)) }
                }

                // ONE movement, because the card only ever moves sideways. A
                // diagonal would be a second state on translationY, started
                // with `async let` so the two land together.
                Button("Move").onClicked {
                    let landed = try await $shift.animateTo(60, .eased(400, easing))
                    if landed { try await $shift.animateTo(0, .eased(400, easing)) }
                }

                Button("Scale").onClicked {
                    let landed = try await $scale.animateTo(1.4, .eased(400, easing))
                    if landed { try await $scale.animateTo(1, .eased(400, easing)) }
                }

                // A movement goes TO a value, never BY one, so a full turn is
                // the author's arithmetic. `setPoint` is where the last one
                // was headed, which is what makes the next press carry on from
                // there rather than start over.
                Button("Spin").onClicked {
                    try await $angle.animateTo(
                        angle.setPoint + 360, .eased(700, easing))
                }
            }

            // Whichever of them is moving; a state standing still is
            // unaffected. Each stop leaves the value where it had got to, so
            // the card stays exactly where the reader saw it stop.
            Button("Stop").onClicked {
                $fade.stop()
                $shift.stop()
                $scale.stop()
                $angle.stop()
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

    var example: Element {
        VStack {
            Border {
                Label("Animate me")
                    .fontSize(17)
                    .textColor(Palette.onAccent)
                    .padding(24, 16)
            }
            // Four DRIVEN properties. Read off a state the host moves, so none
            // of them is on any message after the registration.
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
                // A movement answers whether it ran to the END. Stop says
                // false, and so does a second press taking this one's place -
                // and the way back is not taken over whatever happened
                // instead, which is what lets Stop leave the card where it
                // stood.
                button("Fade") {
                    let landed = try await $fade.animateTo(0.1, .eased(400, easing))
                    if landed { try await $fade.animateTo(1, .eased(400, easing)) }
                }

                // ONE movement, because the card only ever moves sideways. A
                // diagonal would be a second state on translationY, started
                // with `async let` so the two land together.
                button("Move") {
                    let landed = try await $shift.animateTo(60, .eased(400, easing))
                    if landed { try await $shift.animateTo(0, .eased(400, easing)) }
                }

                button("Scale") {
                    let landed = try await $scale.animateTo(1.4, .eased(400, easing))
                    if landed { try await $scale.animateTo(1, .eased(400, easing)) }
                }

                // A movement goes TO a value, never BY one, so a full turn is
                // the author's arithmetic. `setPoint` is where the last one was
                // headed, which is what makes the next press carry on from
                // there rather than start over.
                button("Spin") {
                    try await $angle.animateTo(
                        angle.setPoint + 360, .eased(700, easing))
                }
            }
            .spacing(8)
            .horizontalOptions(.center)

            // Whichever of them is moving; a state standing still is
            // unaffected. Each stop leaves the value where it had got to, so
            // the card stays exactly where the reader saw it stop.
            button("Stop") {
                $fade.stop()
                $shift.stop()
                $scale.stop()
                $angle.stop()
            }
            .horizontalOptions(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Each button moves STATE. `.opacity($fade)` DRIVES the property "
                + "from the state behind it, and `$fade.animateTo(0.1, …)` sends "
                + "everything driven by `fade` to 0.1. `await` says the movement "
                + "is over and the answer says whether it reached the end, which "
                + "is what lets one follow another without a callback.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The state holds BOTH readings: `fade` is 0.1 from the "
                + "line after the call, while `fade.value` is wherever the host "
                + "has got the card to. Nothing is described in between, so the "
                + "whole 400ms costs no renders - and `fade.value = 0.5` instead "
                + "of a movement simply snaps.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("There is no relative turn and no two-axis move. Spin adds 360 "
                + "to where the angle was headed and goes to the sum, so each "
                + "press carries on from the last; Move is a single movement on "
                + "translationX, the only axis this card uses.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Move comes back because the sample says so, not because it "
                + "must: a card left at 60 stays at 60, the state holding it and "
                + "no render being needed to say so. Stop is the other half - it "
                + "leaves the value exactly where it stood, so a movement broken "
                + "off halfway leaves the card where the reader saw it.")
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
