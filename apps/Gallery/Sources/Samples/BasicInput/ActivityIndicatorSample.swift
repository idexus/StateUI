import StateUI

/// A spinner started and stopped by one flag.
struct ActivityIndicatorSample: SampleContent, ExampleContent {
    @State private var loading = true

    static let id = "activityIndicator"
    static let title = "ActivityIndicator"
    static let summary = "The spinner for work with no measurable length."

    static let code = """
        @State private var loading = true

        VStack {
            // The flag is read here, so starting and stopping builds this
            // closure - the spinner itself costs nothing to keep running.
            DebugInfoLabel()

            ActivityIndicator(loading)
                .height(48)

            HStack {
                Label("Working")
                    .verticalAlignment(.center)

                Switch($loading)
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            ActivityIndicator(loading)
                .color(Palette.accent)
                .height(48)

            HStack {
                Label("Working")
                    .fontSize(14)
                    .verticalAlignment(.center)

                Switch($loading)
                    .accessibilityIdentifier("activityIndicator.loading")
                    .accessibilityLabel("Loading")
                    .onColor(Palette.accent)
            }
            .spacing(12)
            .horizontalAlignment(.center)

        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("A still spinner is also an INVISIBLE one on most platforms, which is why "
                + "`ActivityIndicator(loading)` is usually the whole of it - there is "
                + "nothing to hide by hand.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A spinner says \"wait\"; a `ProgressBar` says \"how much longer\". Use the "
                + "bar wherever the work can be counted.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("No binding here, unlike the inputs: nothing about a spinner is the "
                + "reader's to change, so the value only goes one way.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
