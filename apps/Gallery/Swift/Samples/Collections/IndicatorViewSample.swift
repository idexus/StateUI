import StateUI

/// MAUI: IndicatorView.
struct IndicatorViewSample: SampleContent {
    @State private var step = 0

    static let id = "indicatorView"
    static let title = "IndicatorView"
    static let summary = "A place in a sequence, drawn as dots - with or without a carousel."

    static let code = """
        @State private var step = 0

        private static let steps = ["Describe", "Diff", "Send", "Render"]

        VStack {
            Label(Self.steps[step])

            IndicatorView()
                .count(Self.steps.count)
                .position(step)
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)
                .indicatorSize(10)

            IndicatorView()
                .count(Self.steps.count)
                .position(step)
                .indicatorsShape(.square)
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)
                .indicatorSize(10)

            HStack {
                Button("Back")
                    .isEnabled(step > 0)
                    .onClicked { step -= 1 }

                Button("Next")
                    .isEnabled(step < Self.steps.count - 1)
                    .onClicked { step += 1 }
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
