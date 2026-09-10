import StateUI

/// Where a walked value HAS GOT TO, read so many times a second.
struct PacedStateSample: SampleContent {
    static let id = "paced"
    static let title = "A state on a cadence"
    static let summary =
        "A state stands at its DESTINATION while the host walks the control "
        + "there. `.samples($fade, into: $shown, .every(100))` reads where it "
        + "has got to, ten times a second."

    /// What the host walks. Writing it puts the DESTINATION on it at once -
    /// the number below never sweeps, and that is the point of the sample.
    @State private var fade = Journey(1.0)

    /// The reading: where the value had got to when the sample was taken. An
    /// ordinary state, so an ordinary get rebuilds an ordinary view.
    @State private var shown = 1.0

    static let code = """
        // What the host walks, and a state to read it into.
        @State private var fade = Journey(1.0)
        @State private var shown = 1.0

        VStack {
            // WHERE IT IS GOING. A write puts the destination on the state at
            // once, so this number jumps and then stands still.
            VStack {
                DebugInfoLabel()

                Label("going to \\(Int(fade.setPoint * 100))%")
            }

            // WHERE IT HAS GOT TO, read ten times a second. The reading is an
            // ordinary state, so this closure is an ordinary reader of it.
            VStack {
                DebugInfoLabel()

                Label("at \\(Int(shown * 100))%")
            }
            .samples($fade, into: $shown, .every(100))

            BoxView()
                .heightRequest(60)
                .opacity($fade)

            Button("Fade")
                .onClicked { try await $fade.animateTo(0.1, .eased(2000, .cubicOut)) }
        }
        """

    var content: Element {
        VStack {
            // WHERE IT IS GOING: the state itself. A write puts the
            // destination on it at once, so this reading moves once per press
            // and then stands still however long the walk takes.
            VStack {
                DebugInfoLabel()

                Label("going to \(Int(fade.setPoint * 100))%")
                    .fontSize(17)
            }
            .spacing(4)
            .padding(14)
            .backgroundColor(Palette.surface)

            // WHERE IT HAS GOT TO: a reading, taken ten times a second while
            // the host is walking the value, and not at all once it lands.
            VStack {
                DebugInfoLabel()

                Label("at \(Int(shown * 100))%")
                    .fontSize(17)
            }
            .spacing(4)
            .padding(14)
            .backgroundColor(Palette.surface)
            .samples($fade, into: $shown, .every(100))

            BoxView()
                .heightRequest(60)
                .cornerRadius(8)
                .color(Palette.accent)
                .opacity($fade)

            HStack {
                Button("Fade")
                    .automationId("paced.fade")
                    .semanticDescription("Fade the box out")
                    .fontSize(13)
                    .backgroundColor(Palette.accent)
                    .textColor(.white)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .onClicked { try await $fade.animateTo(0.1, .eased(2000, .cubicOut)) }

                Button("Back")
                    .automationId("paced.back")
                    .semanticDescription("Bring the box back")
                    .fontSize(13)
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .backgroundColor(.transparent)
                    .textColor(Palette.subtle)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .onClicked { try await $fade.animateTo(1, .eased(2000, .cubicOut)) }
            }
            .spacing(12)
            .horizontalOptions(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Press Fade and watch the two panels. The top one moves ONCE and "
                + "stands still for the whole two seconds: a state is at its value the "
                + "moment it is written, so a walked value stands at its DESTINATION "
                + "from the first frame. That is what makes the box travel without a "
                + "single render.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("The bottom one counts up as the box fades. It shows a READING - "
                + "where the value had got to when the sample was taken - and the "
                + "reading is an ordinary state, so the closure showing it is an "
                + "ordinary reader rebuilt by an ordinary write.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("It stops by itself. A reading copies only what changed, and the host "
                + "stops sending the moment the value lands - so the count settles and "
                + "nothing is asked for after that. Press Fade again and it starts over.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("It is for a value that decides WHICH VIEWS THERE ARE while it "
                + "travels. A value that is only SHOWN wants a driven text instead - "
                + "`Label($fade.convert { … })` - which the host works out on its own "
                + "frames and which costs no render at all.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
