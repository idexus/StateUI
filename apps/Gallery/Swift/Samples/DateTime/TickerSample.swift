import StateUI

/// The same countdown as Task.sleep, out of the library's own timer.
struct TickerSample: SampleContent {
    /// `@State` keeps the instance across renders; a tick asks for the render
    /// itself, naming the ticker - so the views that read it are rebuilt and
    /// the rest of the tree is left alone. Nothing here subscribes to anything.
    @State private var ticker = Ticker(every: .seconds(1), limit: 30)

    static let id = "ticker"
    static let title = "Ticker"
    static let summary = "The same countdown from the library's timer - a loop the "
        + "library owns, safe from any thread."

    static let code = """
        @State private var ticker = Ticker(every: .seconds(1), limit: 30)

        VStack {
            Label("\\((ticker.limit ?? 0) - ticker.ticks)")

            ProgressBar(remaining)

            HStack {
                Button(ticker.isRunning ? "Stop" : "Start")
                    .onClicked { ticker.isRunning ? ticker.stop() : ticker.start() }

                Button("Reset")
                    .onClicked { ticker.reset() }
            }

            HStack {
                ForEach([10, 30, 60]) { length in
                    Button("\\(length)s")
                        .onClicked {
                            ticker.reset()
                            ticker.limit = length
                        }
                }
            }
        }
        .onUnloaded { ticker.stop() }

        var remaining: Double {
            let total = ticker.limit ?? 0
            return total == 0 ? 0 : Double(total - ticker.ticks) / Double(total)
        }
        """

    var content: Element {
        VStack {
            Label("\((ticker.limit ?? 0) - ticker.ticks)")
                .fontSize(64)
                .fontAttributes(.bold)
                .textColor(ticker.isFinished ? Palette.subtle : Palette.accent)
                .horizontalTextAlignment(.center)

            ProgressBar(remaining)
                .progressColor(Palette.accent)

            HStack {
                Button(ticker.isRunning ? "Stop" : "Start")
                    .fontSize(13)
                    .padding(20, 6)
                    .onClicked { ticker.isRunning ? ticker.stop() : ticker.start() }

                Button("Reset")
                    .fontSize(13)
                    .padding(20, 6)
                    .onClicked { ticker.reset() }
            }
            .spacing(10)
            .horizontalOptions(.center)

            HStack {
                ForEach([10, 30, 60]) { length in
                    Button("\(length)s")
                        .fontSize(12)
                        .padding(14, 4)
                        .onClicked {
                            ticker.reset()
                            ticker.limit = length
                        }
                }
            }
            .spacing(8)
            .horizontalOptions(.center)
        }
        .spacing(12)
        .onUnloaded { ticker.stop() }
    }

    var notes: Element? {
        VStack {
            Label("The same countdown as the Task.sleep sample, with the loop moved into "
                + "the library. What is left here is a value to read: no flag, no visit "
                + "token, no while - a tick writes what the interface reads and asks "
                + "for the render itself.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("It sleeps to a DEADLINE rather than for a length, so the lateness of "
                + "each lap is spent instead of added up - where a loop written by hand "
                + "adds every one of them.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Starting twice is safe - each run takes a token, and a loop that wakes "
                + "holding an old one returns. Stopping it in .onUnloaded is still the "
                + "reader's to write: a ticker outlives the page unless someone says "
                + "otherwise, which is what makes it usable for something that should "
                + "keep counting.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// How much of the countdown is left, as a fraction for the bar.
    private var remaining: Double {
        let total = ticker.limit ?? 0

        return total == 0 ? 0 : Double(total - ticker.ticks) / Double(total)
    }
}
