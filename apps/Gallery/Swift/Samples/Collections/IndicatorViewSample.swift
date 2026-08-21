import StateUI

/// MAUI: IndicatorView.
struct IndicatorViewSample: SampleContent {
    @State private var step = 0
    @State private var cap = 5.0

    static let id = "indicatorView"
    static let title = "IndicatorView"
    static let summary = "A place in a sequence, drawn as dots - with or without a carousel."

    static let code = """
        @State private var step = 0
        @State private var cap = 5.0

        private static let steps = ["Describe", "Diff", "Send", "Render"]

        VStack {
            Label(Self.steps[step])

            IndicatorView()
                .count(Self.steps.count)
                .position(step)
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)

            IndicatorView()
                .count(Self.steps.count)
                .position(step)
                .indicatorsShape(.square)
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)

            HStack {
                Button("Back")
                    .isEnabled(step > 0)
                    .onClicked { step -= 1 }

                Button("Next")
                    .isEnabled(step < Self.steps.count - 1)
                    .onClicked { step += 1 }
            }

            // Twelve items twice, at two caps. `maximumVisible` is a ceiling
            // on the DOTS and not on the items: `count` is twelve in both
            // rows, and the stepper takes the second row's dots away one at a
            // time.
            Label("Twelve items, maximumVisible(12)")

            IndicatorView()
                .count(12)
                .position(step)
                .maximumVisible(12)
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)

            Label("The same twelve, maximumVisible(\\(Int(cap)))")

            IndicatorView()
                .count(12)
                .position(step)
                .maximumVisible(Int(cap))
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)

            Stepper($cap)
                .minimum(4)
                .maximum(12)

            // One item twice. `hideSingle` is true in MAUI and here, so the
            // left-hand one draws NOTHING at all - a lone dot says nothing
            // about where the reader is - and the right-hand one asks for it.
            HStack {
                VStack {
                    Label("hideSingle(true)")

                    IndicatorView()
                        .count(1)
                        .position(0)
                        .hideSingle(true)
                        .indicatorColor(Palette.outline)
                        .selectedIndicatorColor(Palette.accent)
                }

                VStack {
                    Label("hideSingle(false)")

                    IndicatorView()
                        .count(1)
                        .position(0)
                        .hideSingle(false)
                        .indicatorColor(Palette.outline)
                        .selectedIndicatorColor(Palette.accent)
                }
            }
        }
        """

    private static let steps = ["Describe", "Diff", "Send", "Render"]

    var content: Element {
        VStack {
            Label(Self.steps[step])
                .fontSize(20)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            IndicatorView()
                .count(Self.steps.count)
                .position(step)
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)
                .horizontalOptions(.center)

            IndicatorView()
                .count(Self.steps.count)
                .position(step)
                .indicatorsShape(.square)
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)
                .horizontalOptions(.center)

            HStack {
                Button("Back")
                    .fontSize(13)
                    .padding(16, 6)
                    .isEnabled(step > 0)
                    .onClicked { step -= 1 }

                Button("Next")
                    .fontSize(13)
                    .padding(16, 6)
                    .isEnabled(step < Self.steps.count - 1)
                    .onClicked { step += 1 }
            }
            .spacing(10)
            .horizontalOptions(.center)

            // Twelve items twice, at two caps. `maximumVisible` is a ceiling
            // on the DOTS and not on the items: `count` is twelve in both
            // rows, and the stepper takes the second row's dots away one at a
            // time.
            Label("Twelve items, maximumVisible(12)")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalOptions(.center)

            IndicatorView()
                .count(12)
                .position(step)
                .maximumVisible(12)
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)
                .horizontalOptions(.center)

            Label("The same twelve, maximumVisible(\(Int(cap)))")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalOptions(.center)

            IndicatorView()
                .count(12)
                .position(step)
                .maximumVisible(Int(cap))
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)
                .horizontalOptions(.center)

            Stepper($cap)
                .minimum(4)
                .maximum(12)
                .horizontalOptions(.center)

            // One item twice. `hideSingle` is true in MAUI and here, so the
            // left-hand one draws NOTHING at all - a lone dot says nothing
            // about where the reader is - and the right-hand one asks for it.
            HStack {
                VStack {
                    Label("hideSingle(true)")
                        .fontSize(12)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)

                    IndicatorView()
                        .count(1)
                        .position(0)
                        .hideSingle(true)
                        .indicatorColor(Palette.outline)
                        .selectedIndicatorColor(Palette.accent)
                        .horizontalOptions(.center)
                }
                .spacing(6)

                VStack {
                    Label("hideSingle(false)")
                        .fontSize(12)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)

                    IndicatorView()
                        .count(1)
                        .position(0)
                        .hideSingle(false)
                        .indicatorColor(Palette.outline)
                        .selectedIndicatorColor(Palette.accent)
                        .horizontalOptions(.center)
                }
                .spacing(6)
            }
            .spacing(32)
            .horizontalOptions(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("The usual home for one is under a CarouselView, and MAUI joins the two by "
                + "naming the control. Here both take a `position`, so one @State does it - "
                + "which is also what makes an IndicatorView useful on its own, as above.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`indicatorsShape` is plural and the enum is not: MAUI's property really "
                + "is IndicatorsShape, and the names here are MAUI's. Measured: ANDROID "
                + "and WINDOWS draw the squares; on iOS and Mac Catalyst the second row "
                + "stays round - MAUI's square pass takes a pre-iOS-14 branch there that "
                + "the modern control ignores.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Nothing about it is the reader's to change, so there is no binding "
                + "overload - `position` is told to it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`maximumVisible` is a ceiling on the DOTS: both rows above say "
                + "`count(12)`, and only the number drawn moves as the stepper does - "
                + "which is what keeps a long sequence's dots a readable width. The "
                + "stepper stops at four because the step the buttons move is always one "
                + "of the first four.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`hideSingle` is true in MAUI and here, which is why an indicator over a "
                + "ONE-item list draws nothing at all: a lone dot says nothing about where "
                + "the reader is. The two columns above are that same one-item indicator, "
                + "both ways round.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("And a sizing trap, measured: an `indicatorSize` other than MAUI's "
                + "default 6 is, on iOS and Mac Catalyst, a scale TRANSFORM on the whole "
                + "control that its frame knows nothing about - the look shifts between "
                + "layout passes and can clip. This sample keeps the default.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
