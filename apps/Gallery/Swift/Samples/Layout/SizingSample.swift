import StateUI

/// MAUI: VisualElement.WidthRequest and the four bounds around it.
struct SizingSample: SampleContent {
    static let id = "sizing"
    static let title = "Sizing and clipping"
    static let summary = "How big a view asks to be, the bounds on it, and what happens at the edge."

    static let code = """
        VStack {
            // A request, not an instruction: the layout has the last word.
            BoxView(Palette.accent)
                .widthRequest(120)
                .heightRequest(24)

            // Filling the width, but never past 200.
            BoxView(Palette.accent)
                .heightRequest(24)
                .maximumWidthRequest(200)

            // Filling the width, but never squeezed below 160.
            BoxView(Palette.accent)
                .heightRequest(24)
                .minimumWidthRequest(160)

            // The same ceiling on the other axis, against the same request
            // without it: 80 asked for on the left, 32 allowed on the right.
            HStack {
                BoxView(Palette.outline)
                    .widthRequest(60)
                    .heightRequest(80)
                    .verticalOptions(.start)

                BoxView(Palette.accent)
                    .widthRequest(60)
                    .heightRequest(80)
                    .maximumHeightRequest(32)
                    .verticalOptions(.start)
            }
            .spacing(10)

            // A child drawn past the layout's edge, cut off at it.
            VStack {
                BoxView(Palette.accent)
                    .heightRequest(24)
                    .translationX(60)
            }
            .isClippedToBounds(true)
            .widthRequest(120)
        }
        """

    var content: Element {
        VStack {
            row("widthRequest(120)",
                BoxView(Palette.accent).widthRequest(120).heightRequest(24))

            row("maximumWidthRequest(200)",
                BoxView(Palette.accent).heightRequest(24).maximumWidthRequest(200))

            row("minimumWidthRequest(160)",
                BoxView(Palette.accent).heightRequest(24).minimumWidthRequest(160))

            // The pair is the point: both ask for 80 high, and only the one
            // without a ceiling on it is allowed to have it.
            row("heightRequest(80), then the same with maximumHeightRequest(32)",
                HStack {
                    BoxView(Palette.outline)
                        .widthRequest(60)
                        .heightRequest(80)
                        .verticalOptions(.start)

                    BoxView(Palette.accent)
                        .widthRequest(60)
                        .heightRequest(80)
                        .maximumHeightRequest(32)
                        .verticalOptions(.start)
                }
                .spacing(10))

            row("isClippedToBounds(true)",
                VStack {
                    BoxView(Palette.accent)
                        .heightRequest(24)
                        .translationX(60)
                }
                .isClippedToBounds(true)
                .widthRequest(120))

            row("isClippedToBounds(false)",
                VStack {
                    BoxView(Palette.accent)
                        .heightRequest(24)
                        .translationX(60)
                }
                .isClippedToBounds(false)
                .widthRequest(120))
        }
        .spacing(14)
    }

    var notes: Element? {
        VStack {
            Label("Every one of these is a REQUEST. The layout decides, and a stack that "
                + "has no room to spare will ignore a width it cannot give - which is why "
                + "the bounds are worth saying separately from the size.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`maximumWidthRequest` and `maximumHeightRequest` are the ceiling: a "
                + "view filling its parent stops growing there, and a view that ASKED for "
                + "more than the ceiling gets the ceiling. The minimum pair are the floor, "
                + "and stop it being squeezed.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`isClippedToBounds` is the LAYOUT's edge, and cuts off a child drawn "
                + "past it - here by a translation. It is not the same as a shape given "
                + "to one view.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }

    /// One example with the modifier that made it, so the column reads as a
    /// list of named cases.
    private func row(_ caption: String, _ view: Element) -> Element {
        VStack {
            Label(caption)
                .fontSize(11)
                .textColor(Palette.subtle)

            view
        }
        .spacing(6)
    }
}
