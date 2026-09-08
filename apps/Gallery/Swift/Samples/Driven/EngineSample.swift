import StateUI

/// An ENGINE: arithmetic the host runs on its own frames, keeping what it
/// remembers in `@State` nobody reads.
///
/// The line between the two tools is what this page is for. A value rewritten
/// as another value - a number into words, two numbers into one - is a
/// CONVERSION, and the differ writes that engine for you. An engine is written
/// by hand where the arithmetic REMEMBERS something between frames: here a
/// clock that is running or stopped and the time it has counted, neither of
/// which any conversion of any state could work out.
struct EngineSample: SampleContent {
    /// The reading as it stood when Lap was last pressed - ORDINARY state, so
    /// the same reading that costs nothing driven costs a render here.
    @State private var lap = "-"

    /// What the clock says.
    @State private var reading = "0.0 s"

    /// What the button says.
    @State private var caption = "Start"

    /// Whether the clock is running - ordinary state that no view reads, so
    /// a write to it renders nothing; the engine FOLLOWS it, so a write to it
    /// wakes the engine.
    @State private var running = false

    /// How long the clock has run, in milliseconds - the engine's own to
    /// count up, read by nobody: the reading is worked out FROM it, so
    /// nothing outside this page ever needs the number itself.
    @State private var elapsed = 0.0

    static let id = "engine"
    static let title = "Engine"
    static let summary = "Arithmetic on the host's own frames, remembering where it got to in a state nobody reads - which is what a converter cannot do."

    static let code = """
        @State private var lap = "-"

        @State private var reading = "0.0 s"
        @State private var caption = "Start"

        @State private var running = false      // followed by the engine, read by no view
        @State private var elapsed = 0.0        // the engine's own count

        VStack {
            // Nothing here reads the running time, so this stands at one
            // build while the digits change. Lap IS read, which is what says
            // the reading can move at all.
            DebugInfoLabel()

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

                    // The one write here that IS described, and the one that
                    // costs this button its render.
                    lap = "-"
                }
            }
        }
        .engine(following: $running) { cycle in
            guard running else { return .wait }

            elapsed += cycle.elapsed

            let tenths = Int(elapsed / 100)
            reading = "\\(tenths / 10).\\(tenths % 10) s"

            return .again
        }
        """

    var content: Element {
        VStack {
            // What says the clock below ticks without a render: nothing in
            // this closure reads the running time, so it stands at one build
            // while the digits change sixty times a second. Lap is what says
            // the reading can move at all - it is read here.
            DebugInfoLabel()

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
        .engine(following: $running) { cycle in
            guard running else { return .wait }

            elapsed += cycle.elapsed

            let tenths = Int(elapsed / 100)
            reading = "\(tenths / 10).\(tenths % 10) s"

            return .again
        }
    }

    var notes: Element? {
        VStack {
            Label("AN ENGINE IS FOR ARITHMETIC THAT REMEMBERS. Rewriting one value as "
                + "another - a number into words, two numbers into one - is a "
                + "CONVERSION: `$x.convert { … }`, an engine the differ writes for you, "
                + "and what every other sample here uses. This clock cannot be one: "
                + "what it shows is worked out from how long it has been RUNNING, which "
                + "is not a function of any state on the page. That is what a state "
                + "of the engine's own holds, and what makes this an engine written "
                + "by hand.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`Label().text($reading)` reads its words off a driven state, and the words "
                + "are written by the engine on the display's own frame. The letters "
                + "are what count: driven text is written onto the control only when "
                + "the bytes CHANGE, so a reading that lands on the same tenth writes "
                + "nothing at all - which matters because setting a label's text "
                + "measures it again.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("THE TWO READINGS ARE THE SAME READING. The clock is driven; Lap "
                + "puts that very reading into ordinary `@State`. The reading at the "
                + "top says how many times this closure has been described and "
                + "WHICH value for. Start the clock and let it run for a minute: the "
                + "count does not move. Press Lap once, and it goes up by one and "
                + "says `for lap`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`running` and `elapsed` are ordinary `@State` that no view reads, "
                + "so writing them renders nothing - a step, a running total, "
                + "whatever the sum needs, kept across renders like any state. The "
                + "engine names `$running` in `following:`, which is why tapping Start "
                + "- a handler writing it - wakes the engine that switches on it; the "
                + "engine's own writes wake nothing. And answering `.again` is what "
                + "holds the frame clock: a clock is moved by TIME rather than by "
                + "anything being written, so `.wait` is what lets the display go back "
                + "to sleep until Start is tapped again.")
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
