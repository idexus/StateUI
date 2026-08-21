import StateUI

/// Where `@State` may be written from, and the one move that is forbidden.
///
/// The headline the sample proves on screen: two hundred tasks counting at
/// once all land, because a write to `@State` is whole from any thread. The
/// notes carry the rule the screen cannot show - never hop onto `@MainActor`
/// or `DispatchQueue.main`, and reach for `update` when two tasks change the
/// same state at the same moment.
struct ConcurrentStateSample: SampleContent {
    /// The shared count every task increments. `_total` - the box behind it -
    /// is what the tasks capture; it is Sendable, so it crosses to the
    /// cooperative pool safely.
    @State private var total = 0

    /// How many landed last run, to say out loud that none were lost.
    @State private var expected = 0

    @State private var running = false

    static let id = "concurrentState"
    static let title = "State from tasks"
    static let summary = "Writing @State from many tasks at once - and the one thing you may not do to get there."

    static let code = """
        @State private var total = 0
        @State private var running = false

        VStack {
            Label("\\(total)")

            Button(running ? "Counting…" : "Count from 200 tasks at once")
                .isEnabled(!running)
                .onClicked {
                    running = true
                    total = 0

                    // The BOX, not the view: it is Sendable, so every task
                    // can hold it. `count += 1` from two tasks is a read and
                    // then a write, and two of those race - `update` holds the
                    // state's lock across the read, the change and the write,
                    // so all 200 x 100 land.
                    let counter = _total

                    await withTaskGroup(of: Void.self) { group in
                        for _ in 0 ..< 200 {
                            group.addTask {
                                for _ in 0 ..< 100 { counter.update { $0 + 1 } }
                            }
                        }
                    }

                    running = false
                }
        }

        // WRONG - never do this to "reach the UI thread":
        //
        //     await MainActor.run { total = value }   // hangs on Android/Windows
        //
        // RIGHT - just write it. A handler already runs on the library's own
        // @MainThread, and a plain @State write is safe from any thread anyway:
        //
        //     total = value
        """

    var content: Element {
        VStack {
            Label("\(total)")
                .fontSize(56)
                .fontAttributes(.bold)
                .textColor(total == 0 ? Palette.subtle : Palette.accent)
                .horizontalTextAlignment(.center)

            Label(running
                ? "Counting on 200 tasks at once…"
                : (expected == 0
                    ? "Press to count 200 × 100 on 200 concurrent tasks"
                    : "\(total) of \(expected) landed - none lost"))
                .fontSize(13)
                .textColor(total == expected && expected != 0 ? Palette.accent : Palette.subtle)
                .horizontalTextAlignment(.center)

            Button(running ? "Counting…" : "Count from 200 tasks at once")
                .fontSize(14)
                .fontAttributes(.bold)
                .backgroundColor(running ? Palette.disabled : Palette.accent)
                .textColor(Palette.onAccent)
                .cornerRadius(10)
                .padding(22, 12)
                .isEnabled(!running)
                .horizontalOptions(.center)
                .onClicked {
                    running = true
                    total = 0
                    expected = 200 * 100

                    // The BOX, not the view: it is Sendable, so every task can
                    // hold it. Two tasks doing `count += 1` would each read,
                    // add and write, and lose one another's increments;
                    // `update` runs the three steps under the state's own lock,
                    // so every one of the 20,000 lands.
                    let counter = _total

                    await withTaskGroup(of: Void.self) { group in
                        for _ in 0 ..< 200 {
                            group.addTask {
                                for _ in 0 ..< 100 { counter.update { $0 + 1 } }
                            }
                        }
                    }

                    running = false
                }
        }
        .spacing(16)
    }

    var notes: Element? {
        VStack {
            Label("A `@State` write is whole from ANY thread - a handler, a "
                + "`Task.detached` that worked something out, an `async let` "
                + "child. The value sits behind a lock, the write marks the tree "
                + "and wakes the host from wherever it was made, and a write that "
                + "lands mid-render is kept for the next one. So there is nothing "
                + "to hop back to a UI thread for.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Which is the one move that IS forbidden: never send yourself "
                + "to `@MainActor` or `DispatchQueue.main` to \"reach the UI "
                + "thread\". Nothing drains those in a MAUI app on Android or "
                + "Windows - the main thread is turning the Looper or the WinUI "
                + "pump - so a handler that awaits `MainActor.run { … }` suspends "
                + "at that line and never wakes, silently, on two platforms out "
                + "of four. A handler already runs on the library's own "
                + "@MainThread; you do not move yourself there, and you do not "
                + "need to.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The one thing to reach for: `update` when two tasks change the "
                + "SAME state at the same moment. `count += 1` is a read and then "
                + "a write, and two of them interleave and lose a count; "
                + "`_count.update { $0 + 1 }` holds the state's lock across all "
                + "three steps. This sample counts 20,000 that way and loses none "
                + "- take the `update` out for `counter += 1` from 200 tasks and "
                + "the total comes up short.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
