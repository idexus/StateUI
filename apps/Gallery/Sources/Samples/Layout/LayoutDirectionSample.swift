import StateUI

/// One row laid out left to right, right to left, and as the view above says.
struct LayoutDirectionSample: SampleContent, ExampleContent {
    static let id = "layoutDirection"
    static let title = "Layout direction"
    static let summary = "Laying a view out for a language written right to left."

    // listing: LayoutDirectionSample
    var body: some View {
        VStack {
            row("leftToRight", .leftToRight)
            row("rightToLeft", .rightToLeft)
            row("inherited", .inherited)
        }
        .spacing(16)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A view told `.rightToLeft` mirrors its layout: a row fills from the "
                + "right, padding swaps sides, and text finds its natural alignment at "
                + "the other edge. It is what a language written right to left needs, "
                + "and it is one modifier rather than a second set of layouts.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("It is INHERITED. A view left at `.inherited` - which is the default "
                + "- takes whatever the view above it has, so an application usually says "
                + "it once, high up, and everything below follows.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }

    // listing: LayoutDirectionSample
    /// One row laid out each way, with the value that produced it.
    private func row(_ caption: String, _ direction: LayoutDirection) -> some View {
        VStack {
            Text(caption)
                .fontSize(11)
                .textColor(Palette.subtle)

            // Laid out the way `direction` says - at `.inherited`, the way the
            // view above it is.
            HStack {
                ColorBox(Palette.accent)
                    .width(60)
                    .height(20)

                Text("First")
                Text("Second")
            }
            .spacing(10)
            .layoutDirection(direction)
        }
        .spacing(6)
    }
    // listing: end
}
