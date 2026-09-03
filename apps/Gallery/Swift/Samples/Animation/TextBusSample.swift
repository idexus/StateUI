import StateUI

/// Words on a bus: a reading that changes every frame, and a caption a handler
/// writes.
struct TextBusSample: SampleContent {
    /// How long the clock has run, in milliseconds.
    @Bus private var elapsed = 0.0

    /// What the clock says.
    @Bus private var reading = "0.0 s"

    /// What the button says.
    @Bus private var caption = "Start"

    /// Whether the clock is running - engine-side memory, which nothing
    /// crosses and no view shows.
    @BusState private var running = false

    static let id = "textBus"
    static let title = "Words on a bus"
    static let summary = "A reading written every frame, and a caption written by a tap."

    static let code = """
        @Bus private var elapsed = 0.0
        @Bus private var reading = "0.0 s"
        @Bus private var caption = "Start"

        @BusState private var running = false

        // How often this view has been described.
        let info = debugInfo()

        VStack {
            Label(info).textColor(Palette.accent)

            Label().text($reading)

            HStack {
                Button().text($caption).onClicked {
                    running.toggle()
                    caption = running ? "Stop" : "Start"
                }

                Button("Reset").onClicked {
                    running = false
                    caption = "Start"
                    elapsed = 0
                    reading = "0.0 s"
                }
            }
        }
        .engine { cycle in
            guard running else { return .still }

            elapsed += cycle.elapsed

            let tenths = Int(elapsed / 100)
            reading = "\\(tenths / 10).\\(tenths % 10) s"

            return .moving
        }
        """

    var content: Element {
        // How often this view has been described - which is what says the clock
        // below ticks without one.
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

            HStack {
                Button()
                    .text($caption)
                    .fontSize(13)
                    .padding(14, 6)
                    .onClicked {
                        running.toggle()
                        caption = running ? "Stop" : "Start"
                    }

                button("Reset") {
                    running = false
                    caption = "Start"
                    elapsed = 0
                    reading = "0.0 s"
                }
            }
            .spacing(8)
            .horizontalOptions(.center)
        }
        .spacing(12)
        .engine { cycle in
            guard running else { return .still }

            elapsed += cycle.elapsed

            let tenths = Int(elapsed / 100)
            reading = "\(tenths / 10).\(tenths % 10) s"

            return .moving
        }
    }

    var notes: Element? {
        VStack {
            Label("`Label().text($reading)` reads its words off a bus, and the words "
                + "are written by an engine on the display's own frame. The line at "
                + "the top is `debugInfo()`, which names how many times this view has "
                + "been described: start the clock, let it run, stop it, and it stays "
                + "at ONE. Sixty readings a second, and not one of them is a render.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The letters are what count. A text bus is written onto the control "
                + "only when the bytes CHANGE, so a reading that lands on the same "
                + "tenth writes nothing at all - which matters because setting a "
                + "label's text measures it again.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`@BusState` is what an engine remembers between cycles: any Swift "
                + "value, kept across renders, read and written with nothing crossing "
                + "the boundary and no view showing it. An engine that READ one follows "
                + "it, which is why tapping Start - a handler writing `running` - wakes "
                + "the engine that switches on it. And `.engine` answering `.moving` is "
                + "what holds the frame clock: a clock is moved by TIME rather than by "
                + "anything being written, so `.still` is what lets the display go back "
                + "to sleep.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A button's own caption is on the same kind of bus, written by the "
                + "handler that toggles the clock - so the one tap that starts the "
                + "clock also renames the button, and neither is a render.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// The one button whose caption is its own rather than a bus's.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(14, 6)
            .onClicked(act)
    }
}
