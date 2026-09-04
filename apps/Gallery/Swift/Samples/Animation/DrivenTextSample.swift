import StateUI

/// Words the host carries: a reading that changes every frame, and a caption a handler
/// writes.
struct DrivenTextSample: SampleContent {
    /// The reading as it stood when Lap was last pressed - ORDINARY state, so
    /// the same reading that costs nothing driven costs a render here.
    @State private var lap = "-"

    /// How long the clock has run, in milliseconds.
    @Bus private var elapsed = 0.0

    /// What the clock says.
    @Bus private var reading = "0.0 s"

    /// What the button says.
    @Bus private var caption = "Start"

    /// Whether the clock is running - engine-side memory, which nothing
    /// crosses and no view shows.
    @Phase private var running = false

    static let id = "textState"
    static let title = "Words the host carries"
    static let summary = "A reading written every frame, and a caption written by a tap."

    static let code = """
        @Bus private var elapsed = 0.0
        @Bus private var reading = "0.0 s"
        @Bus private var caption = "Start"

        @Phase private var running = false
        @State private var lap = "-"

        VStack {
            // Off a driven state: written ten times a second, never described.
            Label().text($reading)

            // Off state: the same reading, described every time it lands.
            Label("Lap: \\(lap)")

            HStack {
                Button().text($caption).onClicked {
                    running.toggle()
                    caption = running ? "Stop" : "Start"
                }

                Button("Lap").onClicked { lap = reading }

                Button("Reset").onClicked {
                    running = false
                    caption = "Start"
                    elapsed = 0
                    reading = "0.0 s"
                }
            }
        }
        .engine { cycle in
            guard running else { return .idle }

            elapsed += cycle.elapsed

            let tenths = Int(elapsed / 100)
            reading = "\\(tenths / 10).\\(tenths % 10) s"

            return .running
        }
        """

    var example: Element {
        // The count in the corner is what says the clock below ticks without a
        // render, and the Lap line beside it is what says the count can move
        // at all. Every example in this gallery wears one.
        VStack {
            Border {
                Label()
                    .text($reading)
                    .fontSize(44)
                    .fontAttributes(.bold)
                    .horizontalTextAlignment(.center)
                    .horizontalOptions(.center)
            }
            .padding(24, 16)
            .backgroundColor(Palette.surface)
            .stroke(.transparent)
            .strokeShape(.roundRectangle(12))
            .horizontalOptions(.center)

            Label("Lap: \(lap)")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalOptions(.center)

            HStack {
                Button()
                    .text($caption)
                    .fontSize(13)
                    .padding(14, 6)
                    .onClicked {
                        running.toggle()
                        caption = running ? "Stop" : "Start"
                    }

                button("Lap") { lap = reading }

                button("Reset") {
                    running = false
                    caption = "Start"
                    elapsed = 0
                    reading = "0.0 s"
                    lap = "-"
                }
            }
            .spacing(8)
            .horizontalOptions(.center)
        }
        .spacing(12)
        .engine { cycle in
            guard running else { return .idle }

            elapsed += cycle.elapsed

            let tenths = Int(elapsed / 100)
            reading = "\(tenths / 10).\(tenths % 10) s"

            return .running
        }
    }

    var notes: Element? {
        VStack {
            Label("`Label().text($reading)` reads its words off a driven state, and the words "
                + "are written by an engine on the display's own frame. The letters "
                + "are what count: driven text is written onto the control only when "
                + "the bytes CHANGE, so a reading that lands on the same tenth writes "
                + "nothing at all - which matters because setting a label's text "
                + "measures it again.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("THE TWO READINGS ARE THE SAME READING. The clock is driven; Lap "
                + "puts that very reading into ordinary `@State`. The count in the "
                + "corner says how many times this example has been described and "
                + "WHICH value for. Start the clock and let it run for a minute: the "
                + "count does not move. Press Lap once, and it goes up by one and "
                + "says `for lap`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`@Phase` is what an engine remembers between cycles: any Swift "
                + "value, kept across renders, read and written with nothing crossing "
                + "the boundary and no view showing it. An engine that READ one follows "
                + "it, which is why tapping Start - a handler writing `running` - wakes "
                + "the engine that switches on it. And `.engine(following:)` answering `.running` is "
                + "what holds the frame clock: a clock is moved by TIME rather than by "
                + "anything being written, so `.idle` is what lets the display go back "
                + "to sleep.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A button's own caption is driven the same way, written by the "
                + "handler that toggles the clock - so the one tap that starts the "
                + "clock also renames the button, and neither is a render.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// The buttons whose caption is their own rather than a driven state's.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(14, 6)
            .onClicked(act)
    }
}
