import StateUI

/// MAUI: ActivityIndicator.
struct ActivityIndicatorSample: SampleContent {
    @State private var loading = true

    static let id = "activityIndicator"
    static let title = "ActivityIndicator"
    static let summary = "The spinner for work with no measurable length."

    static let code = """
        @State private var loading = true

        VStack {
            ActivityIndicator(loading)
                .heightRequest(48)

            HStack {
                Label("Working")
                    .verticalOptions(.center)

                Switch($loading)
            }
        }
        """

    var content: Element {
        VStack {
            ActivityIndicator(loading)
                .color(Palette.accent)
                .heightRequest(48)

            HStack {
                Label("Working")
                    .fontSize(14)
                    .verticalOptions(.center)

                Switch($loading)
                    .onColor(Palette.accent)
            }
            .spacing(12)
            .horizontalOptions(.center)

        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Still is also INVISIBLE on most platforms, which is why "
                + "`ActivityIndicator(loading)` is usually the whole of it - there is "
                + "nothing to hide by hand.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A spinner says \"wait\"; a ProgressBar says \"how much longer\". Use the "
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
