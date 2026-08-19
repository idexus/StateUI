import StateUI

/// MAUI: several animations in the air at once, which is what `async let` buys.
struct ConcurrentAnimationSample: SampleContent {
    @State private var playing = false

    /// One number per bar, and ONE piece of state for the four of them.
    /// `$hops[index]` is a binding to one element, and a flight is filed under
    /// the state it is about plus which part of it - so each bar walks on a
    /// channel of its own without four `@State`s.
    @State private var hops = [0.0, 0.0, 0.0, 0.0]

    /// What the stage is washing to. A `Color(light:dark:)`, resolved as it is
    /// written onto the node, exactly as an assigned one would be.
    @State private var wash = Palette.accent

    /// How opaque the caption is.
    @State private var breath = 1.0

    static let id = "concurrentAnimation"
    static let title = "At the same time"
    static let summary = "Animations of different lengths, overlapping rather than queueing."

    static let code = """
        @State private var playing = false

        // One number per bar, and one piece of state for the four of them.
        @State private var hops = [0.0, 0.0, 0.0, 0.0]
        @State private var wash = Palette.accent
        @State private var breath = 1.0

        VStack {
            Border {
                VStack {
                    HStack {
                        ForEach(Array(hops.enumerated()), id: \\.offset) { hop in
                            BoxView(Palette.onAccent)
                                .translationY($hops[hop.offset])
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

                try await $breath.animateTo(1, length: 200)
            }
            .isEnabled(!playing)

            Button("Stop").onClicked {
                playing = false

                // One stop per channel. Each writes what the control had
                // reached back into the state, so the tree stops saying the
                // walk finished - and the bars then have somewhere honest to
                // come home from.
                try await $wash.stop()
                try await $breath.stop()

                for index in hops.indices {
                    try await $hops[index].stop()
                    try await $hops[index].animateTo(0, length: 120)
                }
            }
            .isEnabled(playing)
        }

        /// One beat: two long flights spanning it, the bars hopping inside.
        private func beat(_ n: Int) async throws -> Bool {
            // `async let` starts a flight and does not wait for it, so both of
            // these are walking while the bars below hop. Each is its own
            // CHANNEL - one flight, one answer - and the render that carries
            // them hands all three to the host together.
            async let washing: Bool = $wash.animateTo(
                n.isMultiple(of: 2) ? Palette.brand : Palette.accent,
                length: 1200,
                easing: .cubicInOut)

            async let breathing: Bool = $breath.animateTo(0.25, length: 600, easing: .cubicInOut)

            // 4 bars x 300ms = the 1200ms the wash takes, so the wave crosses
            // the stage exactly once per colour. A hop that did not run to the
            // end is Stop, and the bars after it must not start: each would be
            // a fresh flight over the one being stopped.
            var hopped = true

            for index in hops.indices where hopped {
                hopped = try await $hops[index].animateTo(-26, length: 150, easing: .cubicOut)

                if hopped {
                    hopped = try await $hops[index].animateTo(0, length: 150, easing: .cubicIn)
                }
            }

            // Awaited at the BOTTOM: the beat is over when the longest thing
            // in it is over, not when the last one started is.
            let (washed, breathed) = try await (washing, breathing)

            try await $breath.animateTo(1, length: 300, easing: .cubicInOut)

            return hopped && washed && breathed
        }
        """

    var content: Element {
        VStack {
            Border {
                VStack {
                    HStack {
                        ForEach(Array(hops.enumerated()), id: \.offset) { hop in
                            BoxView(Palette.onAccent)
                                .translationY($hops[hop.offset])
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

                    try await $breath.animateTo(1, length: 200)
                }
                .isEnabled(!playing)

                button("Stop") {
                    playing = false

                    // One stop per channel. Each writes what the control had
                    // reached back into the state, so the tree stops saying the
                    // walk finished - and the bars then have somewhere honest
                    // to come home from.
                    try await $wash.stop()
                    try await $breath.stop()

                    for index in hops.indices {
                        try await $hops[index].stop()
                        try await $hops[index].animateTo(0, length: 120)
                    }
                }
                .isEnabled(playing)
            }
            .spacing(8)
            .horizontalOptions(.center)
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

            Label("A CHANNEL is one flight: one piece of state walking to one target, "
                + "one answer when it lands, however many controls that state moves. "
                + "`async let` starts one without waiting for it, which is why the wash, "
                + "the breath and the hop of the moment are three channels in the air "
                + "together.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The four bars are ONE @State - an array of four numbers - and "
                + "`$hops[2]` is a binding to one of them. A flight is filed under the "
                + "state it is about AND which part of it, so each bar gets a channel of "
                + "its own without four pieces of state to keep in step.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The state is given the target the moment a flight starts, so reading "
                + "`breath` on the next line answers 0.25 rather than what is on the "
                + "screen. The tree describes where the value is going; the control is "
                + "what walks there.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Awaiting the two long ones at the BOTTOM is what keeps this a loop "
                + "rather than a pile: a beat is over when the longest thing in it is "
                + "over, so the next colour never starts over the one before it. Stop is "
                + "stop() on each channel, and each writes back what the control had "
                + "reached - which is what the bars then walk home from.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One beat: two long flights spanning it, the bars hopping inside them.
    ///
    /// - Parameter n: which beat this is, which decides the colour it washes to.
    /// - Returns: whether everything in it ran to the end. False is what Stop
    ///   produces, through `stop()` on each of the three states.
    private func beat(_ n: Int) async throws -> Bool {
        // `async let` starts a flight and does not wait for it, so both of these
        // are walking while the bars below hop. Each is its own CHANNEL - one
        // flight, one answer - and the render that carries them hands all three
        // to the host together.
        async let washing: Bool = $wash.animateTo(
            n.isMultiple(of: 2) ? Palette.brand : Palette.accent,
            length: 1200,
            easing: .cubicInOut)

        async let breathing: Bool = $breath.animateTo(0.25, length: 600, easing: .cubicInOut)

        // 4 bars x 300ms = the 1200ms the wash takes, so the wave crosses the
        // stage exactly once per colour. A hop that did not run to the end is
        // Stop, and the bars after it must not start: each would be a fresh
        // flight over the one being stopped.
        var hopped = true

        for index in hops.indices where hopped {
            hopped = try await $hops[index].animateTo(-26, length: 150, easing: .cubicOut)

            if hopped {
                hopped = try await $hops[index].animateTo(0, length: 150, easing: .cubicIn)
            }
        }

        // Awaited at the BOTTOM: the beat is over when the longest thing in it
        // is over, not when the last one started is.
        let (washed, breathed) = try await (washing, breathing)

        try await $breath.animateTo(1, length: 300, easing: .cubicInOut)

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
