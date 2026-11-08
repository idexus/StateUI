import StateUI

/// Two bars over one job: how much of it is done, and how much is left.
struct ProgressBarSample: SampleContent, ExampleContent {
    // listing: ProgressBarSample
    @State private var done = 3.0
    // listing: end

    static let id = "progressBar"
    static let title = "ProgressBar"
    static let summary = "How far along something is, as a fraction from 0 to 1."

    // listing: ProgressBarSample
    var body: some View {
        VStack {
            // How far along is read here, so every step builds this closure.
            DebugInfoLabel()

            Text("Step \(Int(done)) of \(Int(steps))")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            // A FRACTION, not a count: the division happens here, in Swift,
            // because that is where the numbers are.
            ProgressBar(done / steps)
                .tint(Palette.accent)
                .height(8)

            Stepper($done)
                .accessibilityIdentifier("progressBar.done")
                .accessibilityLabel("Work done")
                .minimum(0)
                .maximum(steps)
                .step(1)
                .horizontalAlignment(.center)

            SectionTitle("What is left")

            // This one shows what is LEFT, so the two move opposite ways.
            ProgressBar(1 - done / steps)
                .tint(Palette.subtle)
                .height(8)

        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A FRACTION, not a percentage and not a count: 0.4 is four tenths of the "
                + "way through, whatever the work is measured in. The step count is divided "
                + "in Swift, because that is where the numbers are. A value outside 0 to 1 "
                + "is clamped, so a bar is never drawn more than full.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A control's purpose is given in its initializer alone - the fraction here, "
                + "`Switch($on)`, `Path(\"M 28,0 ...\")`, `Polygon(points)` - as a value or "
                + "as a state, and no modifier or style gives it again. The second bar shows "
                + "what is LEFT, so the two move opposite ways as the stepper is tapped.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    // listing: ProgressBarSample
    /// How many steps the imaginary job has.
    private var steps: Double { 5 }
    // listing: end
}
