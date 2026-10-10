import StateUI

/// What a press does while a run is still under way: buttons each with a gate
/// of its own, every event that awaits through one, two buttons that share one,
/// work a model starts from its code through the gate a button passes too, and
/// uploads that run side by side through one that says when they are busy.
struct GateSample: SampleContent {
    static let id = "gates"
    static let title = "Gates"
    static let summary = "A press while the last still runs - let go, cancelled, queued or run beside it - and a shared gate."

    var examples: [Example] {
        [
            Example(OwnGates()), Example(AwaitingEvents()), Example(SaveAndDelete()), Example(WorkFromCode()),
            Example(Uploads()),
        ]
    }
}

/// Four buttons, each through a gate of its own.
private struct OwnGates: ExampleContent {
    // listing: OwnGates
    /// How many runs began, and how many came to their end.
    struct Tally: Equatable {
        var started = 0
        var finished = 0
    }

    @State private var ignored = Tally()
    @State private var cancelled = Tally()
    @State private var waited = Tally()
    @State private var unheld = Tally()

    var body: some View {
        VStack {
            Text("Press each button three times, quickly.")
                .textColor(Palette.subtle)

            row("Ignore while running", ignored)
                .onClicked(gate: .ignoreWhileRunning) {
                    ignored.started += 1
                    try await Task.sleep(for: .milliseconds(1500))
                    ignored.finished += 1
                }
                .accessibilityIdentifier("gate.ignore")

            // The run a press cancels ends at its sleep: what it would write
            // after is never written.
            row("Cancel previous", cancelled)
                .onClicked(gate: .cancelPrevious) {
                    cancelled.started += 1
                    try await Task.sleep(for: .milliseconds(1500))
                    cancelled.finished += 1
                }
                .accessibilityIdentifier("gate.cancel")

            row("Wait for previous", waited)
                .onClicked(gate: .waitForPrevious) {
                    waited.started += 1
                    try await Task.sleep(for: .milliseconds(1500))
                    waited.finished += 1
                }
                .accessibilityIdentifier("gate.wait")

            row("None", unheld)
                .onClicked(gate: .none) {
                    unheld.started += 1
                    try await Task.sleep(for: .milliseconds(1500))
                    unheld.finished += 1
                }
                .accessibilityIdentifier("gate.none")
        }
        .spacing(12)
    }

    /// One button, and what its runs did so far.
    private func row(_ caption: String, _ tally: Tally) -> Button {
        Button("\(caption) - started \(tally.started), finished \(tally.finished)")
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A handler that awaits passes through a gate, which says what an event "
                + "does while a run is under way. Ignore lets a press go while a run is under "
                + "way: one run, however often it is pressed meanwhile. Cancel ends the run "
                + "under way and starts its own: "
                + "every press starts, only the last finishes. Wait keeps the presses in "
                + "a queue: each runs after the one before. None runs every press beside "
                + "the others: every one of them finishes. Each of these gates is the "
                + "button's own: a policy given as the gate.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A cancelled run changes nothing afterwards: its task is cancelled, so "
                + "the sleep ends it, and anything it wrote, posted or asked of the host "
                + "after it was cancelled would be refused. A handler with no `await` "
                + "runs whole inside the press and needs no gate.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}

/// Two buttons through one gate, which dims both while either runs.
private struct SaveAndDelete: ExampleContent {
    // listing: SaveAndDelete
    /// One gate for both of the document's actions.
    @State private var document = SharedGate(.ignoreWhileRunning)
    @State private var said = "Saved nothing yet."

    var body: some View {
        VStack {
            Text("Press Save, and watch Delete dim while it saves.")
                .textColor(Palette.subtle)

            HStack {
                Button("Save")
                    .isEnabled(!document.isBusy)
                    .onClicked(gate: document) {
                        said = "Saving…"
                        try await Task.sleep(for: .milliseconds(1500))
                        said = "Saved."
                    }
                    .accessibilityIdentifier("gate.save")

                Button("Delete")
                    .isEnabled(!document.isBusy)
                    .onClicked(gate: document) {
                        said = "Deleting…"
                        try await Task.sleep(for: .milliseconds(1500))
                        said = "Deleted."
                    }
                    .accessibilityIdentifier("gate.delete")
            }
            .spacing(10)

            HStack {
                if document.isBusy {
                    ActivityIndicator(true)
                }
                Text(said)
                    .textColor(Palette.accent)
            }
            .spacing(8)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("A SharedGate kept in a state is shared by every handler written with it: Save "
            + "and Delete pass through one, so neither runs while the other does, and "
            + "its isBusy dims both and turns the indicator meanwhile.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// A model that saves through its own gate, asked by a button and by an autosave.
private struct WorkFromCode: ExampleContent {
    // listing: WorkFromCode
    /// A draft that saves through its own gate, whoever asks.
    @MainActor
    final class Draft {
        let saving = SharedGate(.ignoreWhileRunning)
        @State var saves = 0

        /// Saves, unless a save is under way: the gate lets this one go.
        func save() {
            Task(gate: saving) {
                try await Task.sleep(for: .milliseconds(1500))
                self.saves += 1
            }
        }
    }

    @State private var draft = Draft()
    @State private var autosave = Ticker(every: .seconds(3))

    var body: some View {
        VStack {
            Text("Start the autosave, and watch Save dim while it saves.")
                .textColor(Palette.subtle)

            HStack {
                // No await: the press asks the draft, whose own gate decides.
                Button("Save")
                    .isEnabled(!draft.saving.isBusy)
                    .onClicked { draft.save() }
                    .accessibilityIdentifier("gate.draft.save")

                Button(autosave.isRunning ? "Stop autosave" : "Start autosave")
                    .onClicked { autosave.isRunning ? autosave.stop() : autosave.start() }
                    .accessibilityIdentifier("gate.draft.autosave")
            }
            .spacing(10)

            Text(draft.saving.isBusy ? "Saving…" : "Saves: \(draft.saves)")
                .textColor(Palette.accent)
        }
        .spacing(12)
        .onCreated { autosave.onTick = { draft.save() } }
        .onDestroying { autosave.stop() }
    }
    // listing: end

    var notes: (any View)? {
        Text("Work started from code passes a gate too: `Task(gate: saving) { … }` runs "
            + "as a handler written with the gate would, so the autosave and the button "
            + "never save at once, and isBusy dims Save while either does. The task "
            + "belongs to the gate: no element leaving ends it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// A step with no gate, and each event that awaits through a gate of its own.
private struct AwaitingEvents: ExampleContent {
    // listing: AwaitingEvents
    @State private var count = 0
    @State private var query = ""
    @State private var found = "Nothing searched yet."
    @State private var logging = false
    @State private var logged = 0

    var body: some View {
        VStack {
            // No await: the handler runs whole inside the press and names no gate.
            Button("+1 - \(count)")
                .onClicked { count += 1 }

            // Every letter cancels the search under way: only the last one finishes.
            SearchField($query)
                .onTextChanged(gate: .cancelPrevious) { text in
                    try await Task.sleep(for: .milliseconds(600))
                    found = text.isEmpty ? "Nothing searched yet." : "Found 3 for \"\(text)\"."
                }
            Text(found)
                .textColor(Palette.accent)

            SwitchRow("Log each change", $logging)
            Text("Changes logged: \(logged)")
                .textColor(Palette.subtle)
                // Each change logged beside the others: nothing held back.
                .onChanged(logging, gate: .none) {
                    try await Task.sleep(for: .milliseconds(800))
                    logged += 1
                }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("A handler with no await needs no gate. Every handler that awaits names one - "
            + "a click, the words typed, a change - on every event but `.onCreated` and "
            + "`.onDestroying`, which come once: a handler that awaits without one does not "
            + "compile, and the compiler says what to write.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Uploads that run side by side through one gate, which says when any is under way.
private struct Uploads: ExampleContent {
    // listing: Uploads
    /// Nothing held back, and busy while any upload runs.
    @State private var uploads = SharedGate(.none)
    @State private var sent: [String] = []

    private let files = ["notes.txt", "photo.png", "song.mp3"]

    var body: some View {
        VStack {
            Text("Send all three, quickly.")
                .textColor(Palette.subtle)

            ForEach(files) { file in
                Button("Send \(file)")
                    .onClicked(gate: uploads) {
                        try await Task.sleep(for: .milliseconds(1500))
                        sent.append(file)
                    }
            }

            Text(uploads.isBusy ? "Uploading…" : "Sent: \(sent.isEmpty ? "nothing" : sent.joined(separator: ", "))")
                .textColor(Palette.accent)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("A shared gate that holds nothing back still says when it is busy: "
            + "the uploads run side by side, and the line under them waits for the last.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
