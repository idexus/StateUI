import StateUI

/// MAUI: Stepper.
struct StepperSample: SampleContent {
    @State private var servings = 4.0

    static let id = "stepper"
    static let title = "Stepper"
    static let summary = "A number tapped one step at a time, where a slider is dragged to about right."

    static let code = """
        @State private var servings = 4.0

        VStack {
            Label("Servings: \\(Int(servings))")

            Stepper($servings)
                .minimum(1)
                .maximum(12)
                .increment(1)

            // The same value, stepped by five - and written back by hand,
            // which is what the binding above does for you.
            Stepper(servings)
                .minimum(0)
                .maximum(100)
                .increment(5)
                .onValueChanged { value in servings = value }
        }
        """

    var content: Element {
        VStack {
            Label("Servings: \(Int(servings))")
                .fontSize(22)
                .horizontalTextAlignment(.center)

            Stepper($servings)
                .minimum(1)
                .maximum(12)
                .increment(1)
                .horizontalOptions(.center)

            Label("A Slider for a value with few enough steps to name. This one goes from "
                + "1 to 12 and never lands between two servings - which is what a stepper "
                + "is for.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("A BIGGER STEP")

            Stepper(servings)
                .minimum(0)
                .maximum(100)
                .increment(5)
                .horizontalOptions(.center)
                .onValueChanged { value in servings = value }
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("The same value, stepped by five - `increment` is how far one tap goes, "
            + "and MAUI keeps the value inside the range as it moves.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
