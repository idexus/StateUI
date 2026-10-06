import StateUI

struct TextSample: SampleContent, ExampleContent {
    static let id = "text"
    static let title = "Text"
    static let summary = "Read-only native text with StateUI typography and alignment."

    // listing: TextSample
    var body: some View {
        VStack {
            Text("Plain")
                .fontSize(16)

            Text("Bold")
                .fontSize(16)
                .fontAttributes(.bold)

            Text("Italic, and coloured")
                .fontSize(16)
                .fontAttributes(.italic)
                .textColor(Palette.accent)

            Text("Underlined and struck through")
                .fontSize(16)
                .textDecorations([.underline, .strikethrough])

            Text("Centred, with room around it")
                .fontSize(16)
                .horizontalTextAlignment(.center)
                .padding(8)

            Text("A long line that has nowhere left to go, so it is cut short with an ellipsis")
                .fontSize(16)
                .lineBreak(.tailTruncation)
                .maximumLines(1)

            Text("Letters spaced out")
                .fontSize(16)
                .tracking(3)

            // The height of a line as a MULTIPLE of the font's own: the same
            // two lines packed tight, then opened out.
            HStack {
                Text("Two lines,\nlineHeight 0.8")
                    .fontSize(16)
                    .lineHeight(0.8)

                Text("Two lines,\nlineHeight 2")
                    .fontSize(16)
                    .lineHeight(2)
            }
            .spacing(16)

            // One string in mixed case, drawn twice. The case is the DRAWING;
            // the text stays as it was written.
            Text("One string, drawn in Two Ways")
                .fontSize(16)
                .textCase(.uppercase)

            Text("One string, drawn in Two Ways")
                .fontSize(16)
                .textCase(.lowercase)

            // Text follows the system's text-size setting unless a label says
            // it does not.
            Text("Grows with the system text size")
                .fontSize(16)

            Text("Stays at 16 whatever the system says")
                .fontSize(16)
                .isFontAutoScalingEnabled(false)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The uppercase and the lowercase line are written the same way, in mixed "
                + "case: the transform changes the DRAWING and leaves the text alone.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The last two are both 16 until the system's text-size setting moves - "
                + "iOS ▸ Settings ▸ Display & Brightness ▸ Text Size, Android ▸ Settings ▸ "
                + "Display ▸ Font size. Then the first grows with it and the second stays "
                + "where it is; where the platform offers no such setting, the two never "
                + "differ.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Formatting is expressed by StateUI properties and TextSpan runs; "
                + "the native host remains responsible for shaping and drawing glyphs.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
