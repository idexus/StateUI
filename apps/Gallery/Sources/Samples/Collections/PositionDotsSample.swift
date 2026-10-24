import StateUI

/// Dots marking a place in a sequence: their shape, their cap and a lone one.
struct PositionDotsSample: SampleContent, ExampleContent {
    // listing: PositionDotsSample
    @State private var step = 0
    @State private var cap = 5.0
    // listing: end

    static let id = "positionDots"
    static let title = "PositionDots"
    static let summary = "A place in a sequence, drawn as dots - with or without a run of cards."

    // listing: PositionDotsSample
    private static let steps = ["Describe", "Diff", "Send", "Render"]

    var body: some View {
        VStack {
            // `step` and `cap` are read here, so each press of Back, Next or
            // the stepper builds this closure once.
            DebugInfoLabel()

            Text(Self.steps[step])
                .fontSize(20)
                .fontWeight(.bold)
                .horizontalTextAlignment(.center)

            PositionDots()
                .count(Self.steps.count)
                .position(step)
                .dotColor(Palette.outline)
                .currentDotColor(Palette.accent)
                .horizontalAlignment(.center)

            PositionDots()
                .count(Self.steps.count)
                .position(step)
                .dotShape(.square)
                .dotSize(10)
                .dotColor(Palette.outline)
                .currentDotColor(Palette.accent)
                .horizontalAlignment(.center)

            HStack {
                Button("Back")
                    .isEnabled(step > 0)
                    .onClicked { step -= 1 }

                Button("Next")
                    .isEnabled(step < Self.steps.count - 1)
                    .onClicked { step += 1 }
            }
            .spacing(10)
            .horizontalAlignment(.center)

            // Twelve items twice, at two caps. `maximumVisible` is a ceiling
            // on the DOTS and not on the items: `count` is twelve in both
            // rows, and the stepper takes the second row's dots away one at a
            // time.
            Text("Twelve items, maximumVisible(12)")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalAlignment(.center)

            PositionDots()
                .count(12)
                .position(step)
                .maximumVisible(12)
                .dotColor(Palette.outline)
                .currentDotColor(Palette.accent)
                .horizontalAlignment(.center)

            Text("The same twelve, maximumVisible(\(Int(cap)))")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalAlignment(.center)

            PositionDots()
                .count(12)
                .position(step)
                .maximumVisible(Int(cap))
                .dotColor(Palette.outline)
                .currentDotColor(Palette.accent)
                .horizontalAlignment(.center)

            Stepper($cap)
                .accessibilityIdentifier("positionDots.cap")
                .accessibilityLabel("How many dots")
                .minimum(4)
                .maximum(12)
                .horizontalAlignment(.center)

            // One item twice. `hidesForSinglePage` is true by default: the
            // left-hand one says so and draws NOTHING at all - a lone dot says
            // nothing about where the user is - and the right-hand one turns
            // it off and draws its dot.
            HStack {
                VStack {
                    Text("hidesForSinglePage(true)")
                        .fontSize(12)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)

                    PositionDots()
                        .count(1)
                        .position(0)
                        .hidesForSinglePage(true)
                        .dotColor(Palette.outline)
                        .currentDotColor(Palette.accent)
                        .horizontalAlignment(.center)
                }
                .spacing(6)

                VStack {
                    Text("hidesForSinglePage(false)")
                        .fontSize(12)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)

                    PositionDots()
                        .count(1)
                        .position(0)
                        .hidesForSinglePage(false)
                        .dotColor(Palette.outline)
                        .currentDotColor(Palette.accent)
                        .horizontalAlignment(.center)
                }
                .spacing(6)
            }
            .spacing(32)
            .horizontalAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The usual home for one is under a GalleryView. Both take a `position`, so "
                + "one @State joins them - which is also what makes a PositionDots useful "
                + "on its own, as above.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Nothing about it is the user's to change, so `position` has no binding "
                + "overload - it is told to it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`maximumVisible` is a ceiling on the DOTS: both rows above say "
                + "`count(12)`, and only the number drawn moves as the stepper does - "
                + "which is what keeps a long sequence's dots a readable width.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`hidesForSinglePage` is true by default, which is why the dots over a "
                + "ONE-item list draws nothing at all: a lone dot says nothing about where "
                + "the user is. The two columns above are those same one-item dots, "
                + "both ways round.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
