import StateUI

/// Several movements in the air at once, which is what `async let` buys.
struct ConcurrentAnimationSample: SampleContent {
    @State private var playing = false

    /// One driven state per bar. FOUR of them rather than an array, because a
    /// driven state is ONE image the host reads: a binding into an array has no
    /// image of its own, so there would be nothing for the host to read a bar's
    /// place off. Four names is what four independent movements cost.
    @State(describing: .none) private var hop0 = AnimatedValue(0.0)
    @State(describing: .none) private var hop1 = AnimatedValue(0.0)
    @State(describing: .none) private var hop2 = AnimatedValue(0.0)
    @State(describing: .none) private var hop3 = AnimatedValue(0.0)

    /// What the stage is washing to. A `Color(light:dark:)` cannot be driven -
    /// nothing here is described, so nothing can pick a half - so the palette
    /// is asked for the one colour and that is what travels.
    @State(describing: .none) private var wash = AnimatedValue(Palette.accent)

    /// How opaque the caption is.
    @State(describing: .none) private var breath = AnimatedValue(1.0)

    /// The four bars, in order - one place to write the list, read by both the
    /// view and the beat.
    private var bars: [Binding<AnimatedValue<Double>>] { [$hop0, $hop1, $hop2, $hop3] }

    static let id = "concurrentAnimation"
    static let title = "At the same time"
    static let summary = "Movements of different lengths, overlapping rather than queueing."

    static let code = """
        @State private var playing = false

        // One driven state per bar: a driven state is ONE image the host reads,
        // so a binding into an array has nothing for it to read.
        @State(describing: .none) private var hop0 = AnimatedValue(0.0)
        @State(describing: .none) private var hop1 = AnimatedValue(0.0)
        @State(describing: .none) private var hop2 = AnimatedValue(0.0)
        @State(describing: .none) private var hop3 = AnimatedValue(0.0)

        @State(describing: .none) private var wash = AnimatedValue(Palette.accent)
        @State(describing: .none) private var breath = AnimatedValue(1.0)

        private var bars: [Binding<AnimatedValue<Double>>] { [$hop0, $hop1, $hop2, $hop3] }

        VStack {
            Border {
                VStack {
                    HStack {
                        ForEach(Array(bars.enumerated()), id: \\.offset) { bar in
                            BoxView(Palette.onAccent)
                                .translationY(bar.element)
                                .widthRequest(14)
                                .heightRequest(46)
                                .verticalOptions(.end)
                        }
                    }
                    .heightRequest(92)

                    Label("in concert")
                        .opacity($breath)
                }
            }
            .backgroundColor($wash)

            Button("Play").onClicked {
                guard !playing else { return }
                playing = true

                var n = 0

                while playing {
                    let finished = try await beat(n)
                    n += 1

                    // A beat that did not run to the end is what Stop
                    // produces, and starting another over it would fight
                    // whoever pressed it.
                    if !finished { playing = false }
                }

                try await $breath.animateTo(1, .eased(200))
            }
            .isEnabled(!playing)

            Button("Stop").onClicked {
                playing = false

                // One stop per state, each leaving the value where it had got
                // to - which is what the bars then come home from.
                $wash.stop()
                $breath.stop()

                for bar in bars {
                    bar.stop()
                    try await bar.animateTo(0, .eased(120))
                }
            }
            .isEnabled(playing)
        }
        .onUnloaded { playing = false }

        /// One beat: two long movements spanning it, the bars hopping inside.
        private func beat(_ n: Int) async throws -> Bool {
            // `async let` starts a movement and does not wait for it, so both
            // of these are running while the bars below hop. Each is its own
            // value on its own state, and the host carries all three on the
            // same frames.
            async let washing: Bool = $wash.animateTo(
                n.isMultiple(of: 2) ? Palette.brand : Palette.accent,
                .eased(1200, .cubicInOut))

            async let breathing: Bool = $breath.animateTo(0.25, .eased(600, .cubicInOut))

            // 4 bars x 300ms = the 1200ms the wash takes, so the wave crosses
            // the stage exactly once per colour. A hop that did not run to the
            // end is Stop, and the bars after it must not start: each would be
            // a fresh movement over the one being stopped.
            var hopped = true

            for bar in bars where hopped {
                hopped = try await bar.animateTo(-26, .eased(150, .cubicOut))

                if hopped {
                    hopped = try await bar.animateTo(0, .eased(150, .cubicIn))
                }
            }

            // Awaited at the BOTTOM: the beat is over when the longest thing
            // in it is over, not when the last one started is.
            let (washed, breathed) = try await (washing, breathing)

            try await $breath.animateTo(1, .eased(300, .cubicInOut))

            return hopped && washed && breathed
        }
        """

    var content: Element {
        VStack {
            Border {
                VStack {
                    HStack {
                        ForEach(Array(bars.enumerated()), id: \.offset) { bar in
                            BoxView(Palette.onAccent)
                                .translationY(bar.element)
                                .widthRequest(14)
                                .heightRequest(46)
                                .verticalOptions(.end)
                        }
                    }
                    .spacing(10)
                    .horizontalOptions(.center)
                    .heightRequest(92)

                    Label("in concert")
                        .opacity($breath)
                        .fontSize(15)
                        .textColor(Palette.onAccent)
                        .horizontalTextAlignment(.center)
                }
                .spacing(4)
                .padding(16)
            }
            .backgroundColor($wash)
            .stroke(.transparent)
            .strokeShape(.roundRectangle(12))

            HStack {
                button("Play") {
                    guard !playing else { return }
                    playing = true

                    var n = 0

                    while playing {
                        let finished = try await beat(n)
                        n += 1

                        if !finished { playing = false }
                    }

                    try await $breath.animateTo(1, .eased(200))
                }
                .isEnabled(!playing)

                button("Stop") {
                    playing = false

                    // One stop per state, each leaving the value where it had
                    // got to, so the bars have somewhere honest to come home
                    // from.
                    $wash.stop()
                    $breath.stop()

                    for bar in bars {
                        bar.stop()
                        try await bar.animateTo(0, .eased(120))
                    }
                }
                .isEnabled(playing)
            }
            .spacing(8)
            .horizontalOptions(.center)
        }
        .onUnloaded {
            playing = false
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("One press, and three things move at once for as long as it runs: "
                + "the wash across the stage, the caption breathing, and the bars "
                + "hopping one after another inside both.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Every one of them is a DRIVEN state: the host reads the value off "
                + "the state on its own frames, so a beat of 1200ms costs no renders "
                + "at all however many things are moving inside it. `async let` starts "
                + "a movement without waiting for it, which is why the wash, the breath "
                + "and the hop of the moment are three in the air together.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The four bars are FOUR states, one each, because a driven state is "
                + "one image the host reads - a binding into an array of numbers has no "
                + "image of its own, so there would be nothing to read a bar's place off. "
                + "The list of bindings is what keeps the loop short.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A state holds both readings at once: `breath.setPoint` is 0.25 on the "
                + "line after the movement starts, while `breath.value` is whatever is "
                + "on the screen. That is what lets one movement follow another with "
                + "nothing to put back afterwards.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Awaiting the two long ones at the BOTTOM is what keeps this a loop "
                + "rather than a pile: a beat is over when the longest thing in it is "
                + "over, so the next colour never starts over the one before it. Stop is "
                + "stop() on each state, and each leaves its value where it stood - "
                + "which is what the bars then come home from.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One beat: two long movements spanning it, the bars hopping inside them.
    ///
    /// - Parameter n: which beat this is, which decides the colour it washes to.
    /// - Returns: whether everything in it ran to the end. False is what Stop
    ///   produces, through `stop()` on each of the states.
    private func beat(_ n: Int) async throws -> Bool {
        // `async let` starts a movement and does not wait for it, so both of
        // these are running while the bars below hop. Each is its own value on
        // its own state, and the host carries all three on the same frames.
        async let washing: Bool = $wash.animateTo(
            n.isMultiple(of: 2) ? Palette.brand : Palette.accent,
            .eased(1200, .cubicInOut))

        async let breathing: Bool = $breath.animateTo(0.25, .eased(600, .cubicInOut))

        // 4 bars x 300ms = the 1200ms the wash takes, so the wave crosses the
        // stage exactly once per colour. A hop that did not run to the end is
        // Stop, and the bars after it must not start: each would be a fresh
        // movement over the one being stopped.
        var hopped = true

        for bar in bars where hopped {
            hopped = try await bar.animateTo(-26, .eased(150, .cubicOut))

            if hopped {
                hopped = try await bar.animateTo(0, .eased(150, .cubicIn))
            }
        }

        // Awaited at the BOTTOM: the beat is over when the longest thing in it
        // is over, not when the last one started is.
        let (washed, breathed) = try await (washing, breathing)

        try await $breath.animateTo(1, .eased(300, .cubicInOut))

        return hopped && washed && breathed
    }

    /// One of the buttons, both of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(14, 6)
            .onClicked(act)
    }
}
