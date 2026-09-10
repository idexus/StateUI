import StateUI

/// Three roads to the same walking number, and what each one costs.
struct PacedStateSample: SampleContent {
    static let id = "paced"
    static let title = "A state on a cadence"
    static let summary =
        "One value the host is walking, shown three ways - by a converter, by "
        + "a read of its journey, and by a reading taken ten times a second. "
        + "Watch the three build counts."

    /// What the host walks. A write puts the DESTINATION on it at once, and
    /// the host walks the control there on its own frames.
    @State private var fade = 1.0

    /// The reading the third column shows: where the value had got to when the
    /// sample was taken. An ordinary state, so an ordinary get reads it.
    @State private var shown = 1.0

    static let code = """
        @State private var fade = 1.0
        @State private var shown = 1.0

        VStack {
            // A CONVERTER - the host works the words out on its own frames.
            // NO RENDER AT ALL, however long the walk.
            VStack {
                DebugInfoLabel()

                Label($fade.convert { "going to \\(Int($0 * 100))%" })
            }

            // THE JOURNEY - this closure reads where the value IS, which the
            // host writes every frame it moves. ONE RENDER A FRAME.
            VStack {
                DebugInfoLabel()

                Label("at \\(Int($fade.journey.value * 100))%")
            }

            // A READING - taken ten times a second into an ordinary state,
            // which this closure reads. ONE RENDER A WINDOW.
            VStack {
                DebugInfoLabel()

                Label("at \\(Int(shown * 100))%")
            }
            .samples($fade, into: $shown, .every(100))

            BoxView()
                .heightRequest(60)
                .opacity($fade)

            Button("Fade")
                .onClicked { try await $fade.journey.move(to: 0.1, .eased(2000, .cubicOut)) }
        }
        """

    var content: Element {
        VStack {
            // A CONVERTER. The host works the words out on its own frames and
            // wears them, so nothing here is described again - this count
            // stands still for the whole walk.
            VStack {
                DebugInfoLabel()

                Label($fade.convert { "going to \(Int($0 * 100))%" })
                    .fontSize(17)
            }
            .spacing(4)
            .padding(14)
            .backgroundColor(Palette.surface)

            // THE JOURNEY. This closure reads where the value IS, and the host
            // writes that lane every frame - so it is built again on every one
            // of them, printing a number that moves because the value does.
            VStack {
                DebugInfoLabel()

                Label("at \(Int($fade.journey.value * 100))%")
                    .fontSize(17)
            }
            .spacing(4)
            .padding(14)
            .backgroundColor(Palette.surface)

            // A READING, ten times a second, into an ordinary state. Same
            // number, a tenth of the builds.
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
                    .onClicked { try await $fade.journey.move(to: 0.1, .eased(2000, .cubicOut)) }

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
                    .onClicked { try await $fade.journey.move(to: 1, .eased(2000, .cubicOut)) }
            }
            .spacing(12)
            .horizontalOptions(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Press Fade and read the three counts. The first stands still for the "
                + "whole two seconds, the second counts up once a frame, the third about "
                + "ten times a second. One value, three ways of showing it, and the "
                + "difference between them is the whole of what this page is about.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("A state is at its value the moment it is written. `move(to:)` puts "
                + "the DESTINATION on the state at once and the host walks the control "
                + "there - which is what lets the box travel without a single render. "
                + "`fade` is that destination; `$fade.journey.value` is where the box "
                + "has got to.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("A READ OF THE JOURNEY IS A BUILD PER FRAME. The host writes where "
                + "the value is on every frame it moves, and a closure that printed it "
                + "asked to see every one of them. A closure that prints `fade` alone is "
                + "built once per write, the destination never moving in between. That "
                + "is the honest cost of a moving number, and why the first column is a "
                + "converter.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("A reading is the middle road: where the value had got to when the "
                + "sample was taken, copied into an ordinary state. It stops by itself - "
                + "a reading writes only what changed, and the host stops sending the "
                + "moment the value lands.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Which to reach for: a converter where the value is only SHOWN, since "
                + "it costs no render at all; a reading where it decides WHICH VIEWS "
                + "THERE ARE while it travels; the journey itself where every frame "
                + "matters and the closure is small.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
