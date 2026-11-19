import StateUI

/// A card's opacity, sideways translation, scale and rotation, each driven by a state.
@MainActor
struct AnimationSample: SampleContent, ExampleContent {
    // listing: AnimationSample
    @State private var curve = Easing.linear

    /// The four values the card is drawn from, one per thing a button moves.
    ///
    /// Each is DRIVEN on the card below - the property is read off the state
    /// on the host's own frames rather than described - so a four-hundred
    /// millisecond journey costs no renders at all. A card that names none
    /// of them has nothing to move.
    @State private var fade = 1.0
    @State private var shift = 0.0
    @State private var scale = 1.0
    @State private var angle = 0.0
    // listing: end

    static let id = "animation"
    static let title = "Animations"
    static let summary = "Fade, move, scale and spin a view by sending the driven state behind it."

    // listing: AnimationSample
    static let curves: [Easing] = [.linear, .cubicInOut, .bounceOut, .backOut]

    var body: some View {
        VStack {
            // A curve chosen builds this closure once; the four journeys are
            // the host's, so a button pressed builds nothing.
            DebugInfoLabel()

            ZStack {
                Text("Animate me")
                    .fontSize(17)
                    .textColor(Palette.onBrand)
                    .padding(horizontal: 24, vertical: 16)
            }
            .style(.card)
            // Four DRIVEN properties. The host reads each off the state it
            // moves, so none is in a patch after the one that registers it.
            .opacity($fade)
            .translationX($shift)
            .scale($scale)
            .rotation($angle)
            .background(Palette.brand)
            .stroke(Palette.accent)
            .shape(.roundedRectangle(32))
            .horizontalAlignment(.center)

            Picker(Self.curves, selection: $curve, caption: Self.name)
                .accessibilityIdentifier("animation.curve")
                .accessibilityLabel("Easing curve")
                .placeholder("Easing")

            HStack {
                // A movement answers HOW IT ENDED. Stop makes it `.stopped` -
                // and a second press cancels this run, the buttons passing
                // through `.cancelPrevious` - so the way back is taken only
                // where the way out was `.reached`, which is what lets Stop
                // leave the card where it stood.
                button("Fade") {
                    let out = try await $fade.journey.move(to: 0.1, .eased(.milliseconds(400), curve: curve)).result()
                    if case .reached = out {
                        try await $fade.journey.move(to: 1, .eased(.milliseconds(400), curve: curve)).result()
                    }
                }

                // ONE movement, because the card only ever moves sideways. A
                // diagonal would be a second state on translationY, sent
                // beside this one before either is awaited, so the two land
                // together.
                button("Move") {
                    let out = try await $shift.journey.move(to: 60, .eased(.milliseconds(400), curve: curve)).result()
                    if case .reached = out {
                        try await $shift.journey.move(to: 0, .eased(.milliseconds(400), curve: curve)).result()
                    }
                }

                button("Scale") {
                    let out = try await $scale.journey.move(to: 1.4, .eased(.milliseconds(400), curve: curve)).result()
                    if case .reached = out {
                        try await $scale.journey.move(to: 1, .eased(.milliseconds(400), curve: curve)).result()
                    }
                }

                // A movement goes TO a value, never BY one, so a full turn is
                // the author's arithmetic. The state is where the last one was
                // headed, which is what makes the next press carry on from
                // there rather than start over.
                button("Spin") {
                    try await $angle.journey.move(to: angle + 360, .eased(.milliseconds(700), curve: curve)).result()
                }
            }
            .spacing(8)
            .horizontalAlignment(.center)

            // Whichever of them is moving; a state standing still is
            // unaffected. Each stop leaves the value where it had got to, so
            // the card stays exactly where the user saw it stop.
            button("Stop") {
                $fade.journey.stop()
                $shift.journey.stop()
                $scale.journey.stop()
                $angle.journey.stop()
            }
            .horizontalAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Each button moves STATE. `.opacity($fade)` DRIVES the property "
                + "from the state behind it, and `$fade.journey.move(to: 0.1, …)` sends "
                + "everything driven by `fade` to 0.1 at once. `result()` waits until "
                + "the movement is over and answers how it ended - reached, stopped, "
                + "superseded - which is what lets one follow another without a callback.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Where it is going and where it has got to are two readings: `fade` is "
                + "0.1 from the moment the movement is sent, while `$fade.journey.sample` "
                + "says where the host has got the card to. Nothing is described in between, so the "
                + "whole 400ms costs no renders - and `$fade.journey.snap(to: 0.5)` "
                + "puts the card there at once, with no movement.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("There is no relative turn and no two-axis move. Spin adds 360 "
                + "to where the angle was headed and goes to the sum, so each "
                + "press carries on from the last; Move is a single movement on "
                + "translationX, the only axis this card uses.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Move comes back because the sample says so, not because it "
                + "must: a card left at 60 stays at 60, the state holding it and "
                + "no render being needed to say so. Stop is the other half - it "
                + "leaves the value exactly where it stood, so a movement broken "
                + "off halfway leaves the card where the user saw it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    // listing: AnimationSample
    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .onClicked(policy: .cancelPrevious, act)
    }

    /// What the picker calls a curve.
    static func name(_ curve: Easing) -> String {
        switch curve {
        case .cubicInOut: "Cubic in-out"
        case .bounceOut: "Bounce out"
        case .backOut: "Back out"
        default: "Linear"
        }
    }
    // listing: end
}
