import StateUI

/// A countdown written by hand: a loop, a sleep and a flag.
struct TaskSleepSample: SampleContent, ExampleContent {
    // listing: TaskSleepSample
    /// Whole seconds left. The interface reads this, so writing it is the whole
    /// of "tick".
    @State private var remaining = 0

    /// The countdown this run started from, for the bar's fraction.
    @State private var total = 30

    @State private var running = false
    // listing: end

    static let id = "taskSleep"
    static let title = "Task.sleep"
    static let summary = "A countdown written by hand - a loop that sleeps, and what it costs."

    // listing: TaskSleepSample
    var body: some View {
        VStack {
            // The countdown is read here, so every step builds this closure.
            DebugInfoLabel()

            Text("\(remaining)")
                .fontSize(64)
                .fontAttributes(.bold)
                .textColor(remaining == 0 ? Palette.subtle : Palette.accent)
                .horizontalTextAlignment(.center)

            ProgressBar(total == 0 ? 0 : Double(remaining) / Double(total))
                .tint(Palette.accent)

            HStack {
                // A press while the loop runs cancels it - Stop, or Start
                // straight after Reset - so no two loops count together.
                Button(running ? "Stop" : "Start")
                    .onClicked(gate: .cancelPrevious) {
                        if running {
                            running = false
                            return
                        }

                        if remaining == 0 { remaining = total }

                        running = true

                        // Plain Swift concurrency, on every platform: when the
                        // sleep comes due, the handler resumes on `MainActor` -
                        // the thread the host draws on - with no `Timer`
                        // anywhere.
                        while running && remaining > 0 {
                            try await Task.sleep(for: .seconds(1))

                            guard running else { return }

                            remaining -= 1
                        }

                        running = false
                    }

                Button("Reset")
                    .onClicked {
                        running = false
                        remaining = total
                    }
            }
            .spacing(10)
            .horizontalAlignment(.center)

            HStack {
                ForEach([10, 30, 60]) { length in
                    Button("\(length)s")
                        .onClicked {
                            running = false
                            total = length
                            remaining = length
                        }
                }
            }
            .spacing(8)
            .horizontalAlignment(.center)
        }
        .spacing(12)
        .onDestroying { running = false }
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Foundation's `Timer` hangs off a RunLoop, and nothing turns one on "
                + "Android or Windows - so a timer here is a loop that sleeps. The "
                + "handler resumes on the thread the host draws on, which is what makes "
                + "writing state from it ordinary.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Start and Stop are one button whose handler passes through `.cancelPrevious`: a "
                + "press while the loop sleeps cancels it, so Stop and Start within a second "
                + "never leave a sleeping loop to wake and count beside the new one, twice "
                + "as fast. Leaving the page cancels it the same way, and .onDestroying "
                + "clears the flag.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A sleep of one second costs slightly MORE than one second, and a loop "
                + "that sleeps for the interval adds every one of those up - the "
                + "lateness accumulates lap after lap, and a sleeper aimed at a deadline "
                + "avoids it. The Ticker sample beside this one is the same countdown "
                + "with that fixed; the Analog clock takes the other route, asking the "
                + "host the time each lap.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
