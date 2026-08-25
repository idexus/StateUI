import StateUI

/// A ticker that does not repeat, restarted by the work it started.
struct PollSample: SampleContent {
    /// One tick, then stopped - and the tick starts the next round when its
    /// work is done. So the gap is measured from where the work ENDED, and two
    /// rounds can never overlap however long one takes.
    @State private var poll = Ticker(every: .seconds(2), isRepeating: false)

    @State private var status = "Not started"
    @State private var rounds = 0
    @State private var checking = false

    static let id = "poll"
    static let title = "Poll"
    static let summary = "A tick that does the work and starts the next round when it "
        + "is done - so two rounds never overlap."

    static let code = """
        @State private var poll = Ticker(every: .seconds(2), isRepeating: false)
        @State private var status = "Not started"
        @State private var rounds = 0
        @State private var checking = false

        VStack {
            Label(status)
            Label("\\(rounds) round(s)")

            ActivityIndicator(checking)

            Button(poll.isRunning || checking ? "Stop" : "Start")
                .onClicked {
                    if poll.isRunning || checking {
                        poll.stop()
                        checking = false
                        status = "Stopped"
                        return
                    }

                    status = "Waiting"
                    poll.start()
                }
        }
        .onLoaded {
            // Set here rather than in the initializer: the closure reads this
            // view's @State, which does not exist yet while the property that
            // holds the ticker is being initialized.
            poll.onTick = {
                checking = true
                status = "Checking"

                // Work of unknown length, on a task of its own - what a real
                // check would be. The ticker is already stopped by now, which
                // is what makes starting it again below the next round rather
                // than a second one alongside this.
                let answer = await Task.detached {
                    try? await Task.sleep(for: .milliseconds(1200))
                    return "All good"
                }.value

                rounds += 1
                checking = false
                status = "\\(answer) - next check in 2s"

                poll.start()
            }
        }
        .onUnloaded { poll.stop() }
        """

    var content: Element {
        VStack {
            Label(status)
                .fontSize(20)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label("\(rounds) round(s)")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            ActivityIndicator(checking)
                .color(Palette.accent)
                .heightRequest(28)

            Button(poll.isRunning || checking ? "Stop" : "Start")
                .fontSize(13)
                .padding(20, 6)
                .horizontalOptions(.center)
                .onClicked {
                    if poll.isRunning || checking {
                        poll.stop()
                        checking = false
                        status = "Stopped"
                        return
                    }

                    status = "Waiting"
                    poll.start()
                }
        }
        .spacing(12)
        .onLoaded {
            // Set here rather than in the initializer: the closure reads this
            // view's @State, which does not exist yet while the property that
            // holds the ticker is being initialized.
            poll.onTick = {
                checking = true
                status = "Checking"

                // Work of unknown length, on a task of its own - what a real
                // check would be. The ticker is already stopped by now, which
                // is what makes starting it again below the next round rather
                // than a second one alongside this.
                let answer = await Task.detached {
                    try? await Task.sleep(for: .milliseconds(1200))
                    return "All good"
                }.value

                rounds += 1
                checking = false
                status = "\(answer) - next check in 2s"

                poll.start()
            }
        }
        .onUnloaded { poll.stop() }
    }

    var notes: Element? {
        VStack {
            Label("A repeating timer would fire again while the work of the last round "
                + "was still going, and two checks would overlap. This one does not "
                + "repeat: it ticks once, the tick does the work, and the tick starts "
                + "the next round when that work is done - so the gap is measured from "
                + "the END of the work rather than from the start.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The last tick of a run stops the ticker BEFORE running its closure, "
                + "which is what makes that possible: start() on a ticker that is still "
                + "running does nothing, so the round would be lost in silence. Reading "
                + "isRunning therefore says whether another tick is coming, not whether "
                + "the work has finished - which is why the button above asks about both.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The work runs on a task of its own and the restart comes back from "
                + "there, off the thread MAUI draws on. Ticker keeps its state behind a "
                + "lock for exactly this: start, stop and reset are safe from any "
                + "thread.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
