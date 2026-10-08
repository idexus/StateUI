import StateUI

/// A number stepped one at a time, and the same number stepped by five.
struct StepperSample: SampleContent, ExampleContent {
    // listing: StepperSample
    @State private var servings = 4.0
    // listing: end

    static let id = "stepper"
    static let title = "Stepper"
    static let summary = "A number tapped one step at a time, where a slider is dragged to about right."

    // listing: StepperSample
    var body: some View {
        VStack {
            // The count is read here, so every step builds this closure.
            DebugInfoLabel()

            Text("Servings: \(Int(servings))")
                .fontSize(22)
                .horizontalTextAlignment(.center)

            Stepper($servings)
                .accessibilityIdentifier("stepper.servings")
                .accessibilityLabel("Servings")
                .minimum(1)
                .maximum(12)
                .step(1)
                .horizontalAlignment(.center)

            SectionTitle("A bigger step")

            // The same value, stepped by five - and written back by hand,
            // which is what the binding above does for you.
            Stepper(servings)
                .accessibilityIdentifier("stepper.servings.bigStep")
                .accessibilityLabel("Servings, five at a time")
                .minimum(1)
                .maximum(12)
                .step(5)
                .horizontalAlignment(.center)
                .onValueChanged { value in servings = value }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A `Stepper` is a `Slider` for a value with few enough steps to name. This "
                + "one goes from 1 to 12 and never lands between two servings - which is "
                + "what a stepper is for.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The second holds the same value, stepped by five: `step` is how far "
                + "one tap goes, and `minimum` and `maximum` are where the buttons stop.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
