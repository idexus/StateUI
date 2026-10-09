import StateUI

/// How a task reaches `@State`, and the one move that is forbidden.
///
/// The headline the sample proves on screen: two hundred tasks counting at
/// once all land, because each posts its count to the state and every post
/// runs over the last. The notes carry the rule the screen cannot show - never
/// post to `DispatchQueue.main`.
@MainActor
struct ConcurrentStateSample: SampleContent, ExampleContent {
    // listing: ConcurrentStateSample
    /// The shared count every task adds to. `$total` - the binding - is what the
    /// tasks capture: it crosses to the cooperative pool, and is posted to.
    @State private var total = 0

    /// How many landed last run, to say out loud that none were lost.
    @State private var expected = 0

    @State private var running = false
    // listing: end

    static let id = "concurrentState"
    static let title = "State from tasks"
    static let summary = "Writing @State from many tasks at once - and the one thing you may not do to get there."

    // listing: ConcurrentStateSample
    var body: some View {
        VStack {
            // The 200 posts land here as renders: this closure reads `total`, and
            // the reading says how many it was actually built for.
            DebugInfoLabel()

            Text("\(total)")
                .fontSize(56)
                .fontAttributes(.bold)
                .textColor(total == 0 ? Palette.subtle : Palette.accent)
                .horizontalTextAlignment(.center)

            // The proof: after a run, the count equals what was asked for.
            Text(running
                ? "Counting on 200 tasks at once…"
                : (expected == 0
                    ? "Press to count 200 × 100 on 200 concurrent tasks"
                    : "\(total) of \(expected) landed - none lost"))
                .fontSize(13)
                .textColor(total == expected && expected != 0 ? Palette.accent : Palette.subtle)
                .horizontalTextAlignment(.center)

            Button(running ? "Counting…" : "Count from 200 tasks at once")
                .isEnabled(!running)
                .horizontalAlignment(.center)
                .onClicked(.ignoreWhileRunning) {
                    running = true
                    total = 0
                    expected = 200 * 100

                    // The BINDING: a task cannot write the state, which is the
                    // UI thread's, so it posts to it. Each task counts on its
                    // own and posts once; `post { $0 + counted }` runs every
                    // change over the one before, so all 200 land. Their jobs
                    // are queued before the group ends, so the line after it
                    // finds the total whole.
                    let counter = $total

                    await withTaskGroup(of: Void.self) { group in
                        for _ in 0 ..< 200 {
                            group.addTask {
                                var counted = 0
                                for _ in 0 ..< 100 { counted += 1 }
                                counter.post { [counted] in $0 + counted }
                            }
                        }
                    }

                    running = false
                }
        }
        .spacing(16)
    }

    // WRONG - never do this to "reach the UI thread":
    //
    //     DispatchQueue.main.async { total = value }   // never runs on Android/Windows
    //
    // RIGHT - in a handler, just write it: it runs on MainActor, the UI thread.
    // From a task, post it:
    //
    //     total = value
    //     $total.post(value)
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A `@State` is the UI thread's: a handler runs there, on "
                + "`MainActor`, and writes it as it likes. A task off it - a "
                + "`Task.detached` that worked something out, a child of a task "
                + "group - cannot write it, and the compiler says so. It POSTS: "
                + "`$total.post(value)` or `$total.post { $0 + n }` lands in one job "
                + "on the UI thread soon after, whole.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Which is the one move that is forbidden: never post to "
                + "`DispatchQueue.main` to \"reach the UI thread\". Nothing drains it "
                + "on Android or Windows - the UI thread turns the platform's own loop "
                + "instead - so what is posted there never runs, "
                + "silently. A handler already runs on `MainActor`, the UI thread; you "
                + "do not move yourself there, and you do not need to.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The cheap way to count from many tasks: count on each, and post "
                + "once. `post { $0 + counted }` runs every change over the one "
                + "before, in the order posted, so none is lost - 20,000 counts in "
                + "200 posts. Posting every count works too, and costs a hundred "
                + "times the posts.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
