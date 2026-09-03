import StateUI

/// Words on a number: a reading that changes every frame, and a caption a handler
/// writes.
struct DrivenTextSample: SampleContent {
    /// How long the clock has run, in milliseconds.
    @State(describing: .none) private var elapsed = 0.0

    /// What the clock says.
    @State(describing: .none) private var reading = "0.0 s"

    /// What the button says.
    @State(describing: .none) private var caption = "Start"

    /// Whether the clock is running - engine-side memory, which nothing
    /// crosses and no view shows.
    @CycleState private var running = false

    /// The reading as it stood when Lap was last pressed - ORDINARY state, so
    /// the same number that costs nothing on the number costs a render here.
    @State private var lap = "-"

    static let id = "textState"
    static let title = "Words on a number"
    static let summary = "A reading written every frame, and a caption written by a tap."

    static let code = """
        @State(describing: .none) private var elapsed = 0.0
        @State(describing: .none) private var reading = "0.0 s"
        @State(describing: .none) private var caption = "Start"

        @CycleState private var running = false
        @State private var lap = "-"

        // How often this view has been described.
        let info = debugInfo()

        VStack {
            Label(info).textColor(Palette.accent)

            // Off a number: written ten times a second, never described.
            Label().text($reading)

            // Off state: the same number, described every time it lands.
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
        .following { cycle in
            guard running else { return .still }

            elapsed += cycle.elapsed

            let tenths = Int(elapsed / 100)
            reading = "\\(tenths / 10).\\(tenths % 10) s"

            return .moving
        }
        """

    var content: Element {
        // How often this view has been described - which is what says the clock
        // below ticks without one, and the Lap line beside it is what says the
        // count can move at all.
        let info = debugInfo()

        return VStack {
            Label(info)
                .fontSize(12)
                .textColor(Palette.accent)
                .horizontalOptions(.start)

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
        .following { cycle in
            guard running else { return .still }

            elapsed += cycle.elapsed

            let tenths = Int(elapsed / 100)
            reading = "\(tenths / 10).\(tenths % 10) s"

            return .moving
        }
    }

    var notes: Element? {
        VStack {
            Label("`Label().text($reading)` reads its words off a number, and the words "
                + "are written by an engine on the display's own frame. The letters "
                + "are what count: a text number is written onto the control only when "
                + "the bytes CHANGE, so a reading that lands on the same tenth writes "
                + "nothing at all - which matters because setting a label's text "
                + "measures it again.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("THE TWO READINGS ARE THE SAME NUMBER. The clock is on a number; Lap "
                + "puts that very reading into ordinary `@State`. The top line is "
                + "`debugInfo()`, naming how many times this view has been described "
                + "and WHICH value for. Start the clock and let it run for a minute: "
                + "the number does not move. Press Lap once, and it goes up by one "
                + "and says `for lap`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`@CycleState` is what an engine remembers between cycles: any Swift "
                + "value, kept across renders, read and written with nothing crossing "
                + "the boundary and no view showing it. An engine that READ one follows "
                + "it, which is why tapping Start - a handler writing `running` - wakes "
                + "the engine that switches on it. And `.following` answering `.moving` is "
                + "what holds the frame clock: a clock is moved by TIME rather than by "
                + "anything being written, so `.still` is what lets the display go back "
                + "to sleep.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A button's own caption is on the same kind of number, written by the "
                + "handler that toggles the clock - so the one tap that starts the "
                + "clock also renames the button, and neither is a render.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// The buttons whose caption is their own rather than a number's.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(14, 6)
            .onClicked(act)
    }
}
