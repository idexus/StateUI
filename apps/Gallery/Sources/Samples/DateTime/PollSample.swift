import StateUI

/// A ticker that does not repeat, restarted by the work it started.
struct PollSample: SampleContent, ExampleContent {
    // listing: PollSample
    /// One tick, then stopped - and the tick starts the next round when its
    /// work is done. So the gap is measured from where the work ENDED, and two
    /// rounds can never overlap however long one takes.
    @State private var poll = Ticker(every: .seconds(2), isRepeating: false)

    @State private var status = "Not started"
    @State private var rounds = 0
    @State private var checking = false
    // listing: end

    static let id = "poll"
    static let title = "Poll"
    static let summary = "A tick that does the work and starts the next round when it "
        + "is done - so two rounds never overlap."

    // listing: PollSample
    var body: some View {
        VStack {
            // What the poll last answered is read here, so this closure is
            // built as each check begins and again as it answers.
            DebugInfoLabel()

            Text(status)
                .fontSize(20)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Text("\(rounds) round(s)")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            ActivityIndicator(checking)
                .tint(Palette.accent)
                .height(28)

            Button(poll.isRunning || checking ? "Stop" : "Start")
                .horizontalAlignment(.center)
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
        .onCreated {
            // Set here rather than in the initializer: the closure reaches this
            // view's @State and the ticker itself, neither of which exists yet
            // while the property that holds the ticker is being initialized.
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
        .onDestroying { poll.stop() }
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A repeating ticker counts each interval from the last tick's deadline, "
                + "so a long check eats into the gap. This one does not repeat: it ticks "
                + "once, the tick does the work, and the tick starts the next round when "
                + "that work is done - so the gap is measured from the END of the work "
                + "rather than from the start.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The last tick of a run stops the ticker BEFORE running its closure, "
                + "which is what makes that possible: start() on a ticker that is still "
                + "running does nothing, so the round would be lost in silence. Reading "
                + "isRunning therefore says whether another tick is coming, not whether "
                + "the work has finished - which is why the button above asks about both.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The work runs on a detached task of its own. The tick is `@MainActor`, "
                + "so it resumes on the thread the host draws on to write state and "
                + "start the next round. `start`, `stop` and `reset` are safe "
                + "from any thread all the same: `Ticker` keeps its state behind a lock.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
