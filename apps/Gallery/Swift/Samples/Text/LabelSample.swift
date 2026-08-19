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
        }
        """

    var content: Element {
        VStack {
            Label("Plain")
                .fontSize(16)

            Label("Bold")
                .fontSize(16)
                .fontAttributes(.bold)

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

            Label("Every property is MAUI's, camelCased. FontAttributes.Bold is "
                + ".fontAttributes(.bold), never .bold().")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
