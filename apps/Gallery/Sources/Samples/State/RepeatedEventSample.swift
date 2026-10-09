import StateUI

/// What a press does while the run of the press before it is still under way:
/// four buttons, one word each.
@MainActor
struct RepeatedEventSample: SampleContent, ExampleContent {
    // listing: RepeatedEventSample
    /// How many runs began, and how many came to their end.
    struct Tally: Equatable {
        var started = 0
        var finished = 0
    }

    @State private var ignored = Tally()
    @State private var cancelled = Tally()
    @State private var waited = Tally()
    @State private var overlapped = Tally()
    // listing: end

    static let id = "repeatedEvents"
    static let title = "When the event comes again"
    static let summary = "A second press while the first still runs: let go, cancelled, kept waiting, or run beside it."

    // listing: RepeatedEventSample
    var body: some View {
        VStack {
            Text("Press each button three times, quickly.")
                .textColor(Palette.subtle)

            row("Ignore while running", ignored)
                .onClicked(.ignoreWhileRunning) {
                    ignored.started += 1
                    try await Task.sleep(for: .milliseconds(1500))
                    ignored.finished += 1
                }
                .accessibilityIdentifier("repeated.ignore")

            // The run a press cancels ends at its sleep: what it would write
            // after is never written.
            row("Cancel previous", cancelled)
                .onClicked(.cancelPrevious) {
                    cancelled.started += 1
                    try await Task.sleep(for: .milliseconds(1500))
                    cancelled.finished += 1
                }
                .accessibilityIdentifier("repeated.cancel")

            row("Wait for previous", waited)
                .onClicked(.waitForPrevious) {
                    waited.started += 1
                    try await Task.sleep(for: .milliseconds(1500))
                    waited.finished += 1
                }
                .accessibilityIdentifier("repeated.wait")

            row("Overlap", overlapped)
                .onClicked(.overlap) {
                    overlapped.started += 1
                    try await Task.sleep(for: .milliseconds(1500))
                    overlapped.finished += 1
                }
                .accessibilityIdentifier("repeated.overlap")
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
            Text("A handler that awaits says what its event does when it comes again "
                + "while a run is under way. Ignore lets the press go: one run, however "
                + "often it is pressed. Cancel ends the run under way and starts its own: "
                + "every press starts, only the last finishes. Wait keeps the presses in "
                + "a queue: each runs after the one before. Overlap runs every press "
                + "beside the others: all of them finish together.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A cancelled run changes nothing afterwards: its task is cancelled, so "
                + "the sleep ends it, and anything it wrote, posted or asked of the host "
                + "after it was cancelled would be refused. A handler with no `await` "
                + "runs whole inside the press and says nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
