import StateUI

/// MAUI: ProgressBar.
struct ProgressBarSample: SampleContent {
    @State private var done = 3.0

    static let id = "progressBar"
    static let title = "ProgressBar"
    static let summary = "How far along something is, as a fraction from 0 to 1."

    static let code = """
        @State private var done = 3.0

        /// How many steps the imaginary job has.
        private var steps: Double { 5 }

        VStack {
            Label("Step \\(Int(done)) of \\(Int(steps))")

            // A FRACTION, not a count: the division happens here, in Swift,
            // because that is where the numbers are.
            ProgressBar(done / steps)
                .heightRequest(8)

            Stepper($done)
                .minimum(0)
                .maximum(steps)
                .increment(1)

            // A bar built empty carries no value at all, so `.progress` is
            // how one reaches it. This one shows what is LEFT, so the two
            // move opposite ways.
            ProgressBar()
                .progress(1 - done / steps)
                .heightRequest(8)
        }
        """

    var example: Element {
        VStack {
            Label("Step \(Int(done)) of \(Int(steps))")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            ProgressBar(done / steps)
                .progressColor(Palette.accent)
                .heightRequest(8)

            Stepper($done)
                .minimum(0)
                .maximum(steps)
                .increment(1)
                .horizontalOptions(.center)

            Label("A FRACTION, not a percentage and not a count: 0.4 is four tenths of the "
                + "way through, whatever the work is measured in. The step count above is "
                + "divided here, in Swift, because that is where the numbers are.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("MAUI clamps anything outside 0 to 1, so a bar cannot be drawn more than "
                + "full - and a value that says otherwise is a bug worth seeing rather "
                + "than a bar drawn off the edge.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("THE SAME PROPERTY, AS A MODIFIER")

            ProgressBar()
                .progress(1 - done / steps)
                .progressColor(Palette.subtle)
                .heightRequest(8)

        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("`ProgressBar()` carries no value at all, so `.progress` is how one "
                + "reaches it - and it sets the very property the initializer's argument "
                + "sets. This one shows what is LEFT to do, so the two bars move opposite "
                + "ways as the stepper is tapped.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("That pairing is the rule, not this control's quirk: wherever a "
                + "control takes its purpose in the initializer - `Switch($on)`, "
                + "`Picker(items)`, `Path(\"M 28,0 ...\")`, `Polygon(points)` - there is a "
                + "modifier of the same name beside it. The initializer is what a view "
                + "written in place uses; the MODIFIER is what a `Style` needs, and what "
                + "a control built empty and filled in later has.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// How many steps the imaginary job has.
    private var steps: Double { 5 }
}
