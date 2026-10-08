import StateUI

/// How big a view asks to be, the bounds on that request, and clipping.
struct SizingSample: SampleContent, ExampleContent {
    static let id = "sizing"
    static let title = "Sizing and clipping"
    static let summary = "How big a view asks to be, the bounds on it, and what happens at the edge."

    // listing: SizingSample
    var body: some View {
        VStack {
            row("width(120)",
                // A request, not an instruction: the layout has the last word.
                ColorBox(Palette.accent).width(120).height(24))

            row("maximumWidth(200)",
                ColorBox(Palette.accent).height(24).maximumWidth(200))

            row("minimumWidth(160)",
                ColorBox(Palette.accent).height(24).minimumWidth(160))

            // The pair is the point: both ask for 80 high, and only the one
            // without a ceiling on it is allowed to have it.
            row("height(80), then the same with maximumHeight(32)",
                HStack {
                    ColorBox(Palette.outline)
                        .width(60)
                        .height(80)
                        .verticalAlignment(.start)

                    ColorBox(Palette.accent)
                        .width(60)
                        .height(80)
                        .maximumHeight(32)
                        .verticalAlignment(.start)
                }
                .spacing(10))

            // A child drawn past the layout's edge, cut off at it.
            row("clipsContent(true)",
                VStack {
                    ColorBox(Palette.accent)
                        .height(24)
                        .translationX(60)
                }
                .clipsContent(true)
                .width(120))

            row("clipsContent(false)",
                VStack {
                    ColorBox(Palette.accent)
                        .height(24)
                        .translationX(60)
                }
                .clipsContent(false)
                .width(120))
        }
        .spacing(14)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Every one of these is a REQUEST. The layout decides, and a stack that "
                + "has no room to spare will ignore a width it cannot give - which is why "
                + "the bounds are worth saying separately from the size.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`maximumWidth` and `maximumHeight` are the ceiling: a "
                + "view filling its parent stops growing there, and a view that ASKED for "
                + "more than the ceiling gets the ceiling. The minimum pair are the floor, "
                + "and stop it being squeezed.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`clipsContent` is the LAYOUT's edge, and cuts off a child drawn "
                + "past it - here by a translation. It is not the same as a shape given "
                + "to one view.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }

    // listing: SizingSample
    /// One example with the modifier that made it, so the column reads as a
    /// list of named cases.
    private func row<Shown: View>(_ caption: String, _ view: Shown) -> some View {
        VStack {
            Text(caption)
                .fontSize(11)
                .textColor(Palette.subtle)

            view
        }
        .spacing(6)
    }
    // listing: end
}
