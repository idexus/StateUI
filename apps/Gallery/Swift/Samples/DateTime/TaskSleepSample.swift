import StateUI

/// A countdown written by hand: a loop, a sleep and a flag.
struct TaskSleepSample: SampleContent {
    /// Whole seconds left. The interface reads this, so writing it is the whole
    /// of "tick".
    @State private var remaining = 0

    /// The countdown this run started from, for the bar's fraction.
    @State private var total = 30

    @State private var running = false

    /// Which visit to this page the running loop belongs to. Leaving stops the
    /// loop through `.onUnloaded`; the token is what retires one whose unload
    /// never arrived, so a return cannot end up with two loops counting the
    /// same numbers down.
    @State private var visit = 0

    static let id = "taskSleep"
    static let title = "Task.sleep"
    static let summary = "A countdown written by hand - a loop that sleeps, and what it costs."

    static let code = """
        @State private var remaining = 0
        @State private var total = 30
        @State private var running = false
        @State private var visit = 0

        VStack {
            Label("\\(remaining)")

            ProgressBar(total == 0 ? 0 : Double(remaining) / Double(total))

            HStack {
                Button(running ? "Stop" : "Start")
                    .onClicked {
                        if running {
                            running = false
                            return
                        }

                        if remaining == 0 { remaining = total }

                        visit += 1
                        let mine = visit
                        running = true

                        // Plain Swift concurrency, on any platform: the host
                        // parks a thread in stateui_wait_work and a resume
                        // wakes it, so a sleep coming due reaches the handler
                        // without a Timer or a RunLoop anywhere.
                        while running && visit == mine && remaining > 0 {
                            try await Task.sleep(for: .seconds(1))

                            guard running, visit == mine else { return }

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

            HStack {
                ForEach([10, 30, 60]) { length in
                    Button("\\(length)s")
                        .onClicked {
                            running = false
                            total = length
                            remaining = length
                        }
                }
            }
        }
        .onUnloaded { running = false }
        """

    var content: Element {
        VStack {
            Label("\(remaining)")
                .fontSize(64)
                .fontAttributes(.bold)
                .textColor(remaining == 0 ? Palette.subtle : Palette.accent)
                .horizontalTextAlignment(.center)

            ProgressBar(total == 0 ? 0 : Double(remaining) / Double(total))
                .progressColor(Palette.accent)

            HStack {
                Button(running ? "Stop" : "Start")
                    .fontSize(13)
                    .padding(20, 6)
                    .onClicked {
                        if running {
                            running = false
                            return
                        }

                        if remaining == 0 { remaining = total }

                        visit += 1
                        let mine = visit
                        running = true

                        // Plain Swift concurrency, on any platform: the host
                        // parks a thread in stateui_wait_work and a resume
                        // wakes it, so a sleep coming due reaches the handler
                        // without a Timer or a RunLoop anywhere.
                        while running && visit == mine && remaining > 0 {
                            try await Task.sleep(for: .seconds(1))

                            guard running, visit == mine else { return }

                            remaining -= 1
                        }

                        running = false
                    }

                Button("Reset")
                    .fontSize(13)
                    .padding(20, 6)
                    .onClicked {
                        running = false
                        remaining = total
                    }
            }
            .spacing(10)
            .horizontalOptions(.center)

            HStack {
                ForEach([10, 30, 60]) { length in
                    Button("\(length)s")
                        .fontSize(12)
                        .padding(14, 4)
                        .onClicked {
                            running = false
                            total = length
                            remaining = length
                        }
                }
            }
            .spacing(8)
            .horizontalOptions(.center)
        }
        .spacing(12)
        .onUnloaded { running = false }
    }

    var notes: Element? {
        VStack {
            Label("Foundation's Timer hangs off a RunLoop, and nothing turns one in a "
                + "MAUI app on Android or Windows - so a timer here is a loop that "
                + "sleeps. The handler resumes on the thread MAUI draws on, which is "
                + "what makes writing state from it ordinary.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Leaving the page stops it: .onUnloaded clears the flag, and the visit "
                + "token retires a loop whose unload never arrived. Without one, coming "
                + "back would start a second loop counting the same number down twice as "
                + "fast.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A sleep of one second costs slightly MORE than one second, and a loop "
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
