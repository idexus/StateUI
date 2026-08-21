import StateUI

/// MAUI: Label.
struct LabelSample: SampleContent {
    static let id = "label"
    static let title = "Label"
    static let summary = "Read-only text, and the font and alignment properties MAUI puts on it."

    static let code = """
        VStack {
            Label("Plain")

            Label("Bold")
                .fontAttributes(.bold)

            Label("Italic, and coloured")
                .fontAttributes(.italic)
                .textColor(Palette.accent)

            Label("Underlined and struck through")
                .textDecorations([.underline, .strikethrough])

            Label("Centred, with room around it")
                .horizontalTextAlignment(.center)
                .padding(8)

            Label("A long line that has nowhere left to go, so it is cut short with an ellipsis")
                .lineBreakMode(.tailTruncation)
                .maxLines(1)

            Label("Letters spaced out")
                .characterSpacing(3)

            // The height of a line as a MULTIPLE of the font's own: the same
            // two lines packed tight, then opened out.
            HStack {
                Label("Two lines,\\nlineHeight 0.8")
                    .lineHeight(0.8)

                Label("Two lines,\\nlineHeight 2")
                    .lineHeight(2)
            }

            // One string in mixed case, drawn twice. The case is the DRAWING;
            // the text stays as it was written.
            Label("One string, drawn in Two Ways")
                .textTransform(.uppercase)

            Label("One string, drawn in Two Ways")
                .textTransform(.lowercase)

            // Text follows the system's text-size setting unless a label says
            // it does not.
            Label("Grows with the system text size")
                .fontSize(16)

            Label("Stays at 16 whatever the system says")
                .fontSize(16)
                .fontAutoScalingEnabled(false)
        }
        """

    var content: Element {
        VStack {
            Label("Plain")
                .fontSize(16)

            Label("Bold")
                .fontSize(16)
                .fontAttributes(.bold)

            // The string read as markup rather than as written. Left unstyled
            // on purpose: with .html the font and colour modifiers compete
            // with the markup and which wins is the platform's business.
            Label("<b>Bold</b> and <i>italic</i>, read as <u>HTML</u>")
                .textType(.html)

            Label("Italic, and coloured")
                .fontSize(16)
                .fontAttributes(.italic)
                .textColor(Palette.accent)

            Label("Underlined and struck through")
                .fontSize(16)
                .textDecorations([.underline, .strikethrough])

            Label("Centred, with room around it")
                .fontSize(16)
                .horizontalTextAlignment(.center)
                .padding(8)

            Label("A long line that has nowhere left to go, so it is cut short with an ellipsis")
                .fontSize(16)
                .lineBreakMode(.tailTruncation)
                .maxLines(1)

            Label("Letters spaced out")
                .fontSize(16)
                .characterSpacing(3)

            // The height of a line as a MULTIPLE of the font's own: the same
            // two lines packed tight, then opened out.
            HStack {
                Label("Two lines,\nlineHeight 0.8")
                    .fontSize(16)
                    .lineHeight(0.8)

                Label("Two lines,\nlineHeight 2")
                    .fontSize(16)
                    .lineHeight(2)
            }
            .spacing(16)

            Label("One string, drawn in Two Ways")
                .fontSize(16)
                .textTransform(.uppercase)

            Label("One string, drawn in Two Ways")
                .fontSize(16)
                .textTransform(.lowercase)

            Label("Those two lines are written the same way, in mixed case: the transform "
                + "changes the DRAWING and leaves the text alone.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Grows with the system text size")
                .fontSize(16)

            Label("Stays at 16 whatever the system says")
                .fontSize(16)
                .fontAutoScalingEnabled(false)

            Label("Those two are both 16 until the system's text-size setting moves - "
                + "iOS ▸ Settings ▸ Display & Brightness ▸ Text Size, Android ▸ Settings ▸ "
                + "Display ▸ Font size. Then the first grows with it and the second stays "
                + "where it is; where the platform offers no such setting, the two never "
                + "differ.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Every property is MAUI's, camelCased. FontAttributes.Bold is "
                + ".fontAttributes(.bold), never .bold().")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
