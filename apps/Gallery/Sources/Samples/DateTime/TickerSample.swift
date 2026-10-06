import StateUI

/// The same countdown as Task.sleep, out of the library's own timer.
struct TickerSample: SampleContent, ExampleContent {
    // listing: TickerSample
    /// `@State` keeps the instance across renders; a tick asks for the render
    /// itself, naming the ticker - so the views that read it are rebuilt and
    /// the rest of the tree is left alone. Nothing here subscribes to anything.
    @State private var ticker = Ticker(every: .seconds(1), limit: 30)
    // listing: end

    static let id = "ticker"
    static let title = "Ticker"
    static let summary = "The same countdown from the library's timer - a loop the "
        + "library owns, safe from any thread."

    // listing: TickerSample
    var body: some View {
        VStack {
            // The tick is read here, so every second builds this closure -
            // which is what a clock costs when its digits are described.
            DebugInfoLabel()

            Text("\((ticker.limit ?? 0) - ticker.ticks)")
                .fontSize(64)
                .fontAttributes(.bold)
                .textColor(ticker.isFinished ? Palette.subtle : Palette.accent)
                .horizontalTextAlignment(.center)

            ProgressBar(remaining)
                .tint(Palette.accent)

            HStack {
                Button(ticker.isRunning ? "Stop" : "Start")
                    .fontSize(13)
                    .padding(horizontal: 20, vertical: 6)
                    .onClicked { ticker.isRunning ? ticker.stop() : ticker.start() }

                Button("Reset")
                    .fontSize(13)
                    .padding(horizontal: 20, vertical: 6)
                    .onClicked { ticker.reset() }
            }
            .spacing(10)
            .horizontalAlignment(.center)

            HStack {
                ForEach([10, 30, 60]) { length in
                    Button("\(length)s")
                        .fontSize(12)
                        .padding(horizontal: 14, vertical: 4)
                        .onClicked {
                            ticker.reset()
                            ticker.limit = length
                        }
                }
            }
            .spacing(8)
            .horizontalAlignment(.center)
        }
        .spacing(12)
        .onDestroying { ticker.stop() }
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The same countdown as the Task.sleep sample, with the loop moved into "
                + "the library. What is left here is a value to read: no flag, no visit "
                + "token, no while - a tick writes what the interface reads and asks "
                + "for the render itself.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("It sleeps to a DEADLINE rather than for a length, so the lateness of "
                + "each lap is spent instead of added up - where the Task.sleep sample's "
                + "loop adds every one of them.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Starting twice is safe - each run takes a token, and a loop that wakes "
                + "holding an old one returns. Stopping it in .onDestroying is still the "
                + "reader's to write: a ticker outlives the page unless someone says "
                + "otherwise, which is what makes it usable for something that should "
                + "keep counting.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    // listing: TickerSample
    /// How much of the countdown is left, as a fraction for the bar.
    private var remaining: Double {
        let total = ticker.limit ?? 0

        return total == 0 ? 0 : Double(total - ticker.ticks) / Double(total)
    }
    // listing: end
}
