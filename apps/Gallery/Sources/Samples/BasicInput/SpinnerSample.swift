import StateUI

/// A spinner started and stopped by one flag.
struct SpinnerSample: SampleContent, ExampleContent {
    // listing: SpinnerSample
    @State private var loading = true
    // listing: end

    static let id = "spinner"
    static let title = "Spinner"
    static let summary = "Turning while work with no measurable length runs."

    // listing: SpinnerSample
    var body: some View {
        VStack {
            // The flag is read here, so starting and stopping builds this
            // closure - the spinner itself costs nothing to keep running.
            DebugInfoLabel()

            Spinner(loading)
                .tint(Palette.accent)
                .height(48)

            Switch($loading)
                .text("Working")
                .accessibilityIdentifier("spinner.loading")
                .tint(Palette.accent)
                .horizontalAlignment(.center)

        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A still spinner is also an INVISIBLE one on most platforms, which is why "
                + "`Spinner(loading)` is usually the whole of it - there is "
                + "nothing to hide by hand.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A spinner says \"wait\"; a `ProgressBar` says \"how much longer\". Use the "
                + "bar wherever the work can be counted.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("No two-way binding, unlike the inputs: nothing about a spinner is the "
                + "user's to change, so the value only goes one way - `.isAnimating($loading)` "
                + "would carry a state one way too.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
