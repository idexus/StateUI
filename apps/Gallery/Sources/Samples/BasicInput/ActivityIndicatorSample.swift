import StateUI

/// A spinner started and stopped by one flag.
struct ActivityIndicatorSample: SampleContent, ExampleContent {
    // listing: ActivityIndicatorSample
    @State private var loading = true
    // listing: end

    static let id = "activityIndicator"
    static let title = "ActivityIndicator"
    static let summary = "The spinner for work with no measurable length."

    // listing: ActivityIndicatorSample
    var body: some View {
        VStack {
            // The flag is read here, so starting and stopping builds this
            // closure - the spinner itself costs nothing to keep running.
            DebugInfoLabel()

            ActivityIndicator(loading)
                .tint(Palette.accent)
                .height(48)

            HStack {
                Text("Working")
                    .fontSize(14)
                    .verticalAlignment(.center)

                Switch($loading)
                    .accessibilityIdentifier("activityIndicator.loading")
                    .accessibilityLabel("Loading")
                    .tint(Palette.accent)
            }
            .spacing(12)
            .horizontalAlignment(.center)

        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A still spinner is also an INVISIBLE one on most platforms, which is why "
                + "`ActivityIndicator(loading)` is usually the whole of it - there is "
                + "nothing to hide by hand.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A spinner says \"wait\"; a `ProgressBar` says \"how much longer\". Use the "
                + "bar wherever the work can be counted.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("No binding here, unlike the inputs: nothing about a spinner is the "
                + "user's to change, so the value only goes one way.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
