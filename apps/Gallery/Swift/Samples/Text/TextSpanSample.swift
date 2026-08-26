import StateUI

/// MAUI: Span, in the FormattedString a Label's FormattedText holds.
struct TextSpanSample: SampleContent {
    @State private var highlighted = 1

    /// The line the last example colours one word of.
    private let words = ["A", "Label", "has", "one", "TextColor"]

    static let id = "textSpan"
    static let title = "TextSpan"
    static let summary = "Text in more than one colour: a Label's runs, each with a look of its own."

    static let code = """
        @State private var highlighted = 1

        private let words = ["A", "Label", "has", "one", "TextColor"]

        VStack {
            // Two colours in one line, which is what runs are FOR: a MAUI
            // Label has one TextColor, so this is the only way.
            Label()
                .formattedText {
                    TextSpan("let ").textColor(Palette.brand)
                    TextSpan("counter").textColor(Palette.accent)
                    TextSpan(" = 0")
                }

            // A run carries font properties of its own, and what an unset one
            // falls back to is the platform's business.
            Label()
                .formattedText {
                    TextSpan("Sold ")
                    TextSpan("out")
                        .fontAttributes(.bold)
                        .textColor(Palette.onAccent)
                        .backgroundColor(Palette.accent)
                }

            // A loop is the usual way - one run per token, which is how the
            // code block on every page of this gallery is drawn.
            Label()
                .formattedText {
                    ForEach(Array(words.enumerated()), id: \\.offset) { pair in
                        let (index, word) = pair
                        return TextSpan(word + " ")
                            .textColor(index == highlighted ? Palette.accent : Palette.text)
                            .fontAttributes(index == highlighted ? .bold : .none)
                    }
                }

            Button("Move the highlight")
                .onClicked { highlighted = (highlighted + 1) % words.count }

            // Text and formattedText are MUTUALLY EXCLUSIVE - MAUI's rule:
            // assigning FormattedText puts Text back to null. The runs win,
            // being applied last.
            Label("this text never appears")
                .formattedText {
                    TextSpan("the runs win")
                }
        }
        """

    var content: Element {
        VStack {
            Label()
                .formattedText {
                    TextSpan("let ").textColor(Palette.brand)
                    TextSpan("counter").textColor(Palette.accent)
                    TextSpan(" = 0")
                }
                .fontSize(17)
                .fontFamily("Menlo")

            Label("Two colours in one line, which is what runs are for: a MAUI Label has "
                + "one TextColor, so text in two colours is two Spans.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label()
                .formattedText {
                    TextSpan("Sold ")
                        .fontSize(17)
                        .textColor(Palette.text)

                    TextSpan("out")
                        .fontSize(17)
                        .fontAttributes(.bold)
                        .textColor(Palette.onAccent)
                        .backgroundColor(Palette.accent)
                }

            Label("A run carries font and text properties of its own - size, family, weight, "
                + "a background behind those words alone. It is not a view, so there is no "
                + "margin and no size on it: MAUI's Span is a BindableObject, which is the "
                + "tier `TextElement` and `FontElement` are written against.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label()
                .formattedText {
                    ForEach(Array(words.enumerated()), id: \.offset) { pair in
                        let (index, word) = pair
                        return TextSpan(word + " ")
                            .fontSize(17)
                            .textColor(index == highlighted ? Palette.accent : Palette.text)
                            .fontAttributes(index == highlighted ? .bold : .none)
                    }
                }

            Button("Move the highlight")
                .onClicked { highlighted = (highlighted + 1) % words.count }

            Label("A loop is the usual way, one run per token - which is how the code block "
                + "under every example here is drawn. Moving the highlight sends the two runs "
                + "that changed and nothing else; the host keeps the rest of the line, the "
                + "same way it keeps a list of rows.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("this text never appears")
                .formattedText {
                    TextSpan("the runs win")
                        .fontSize(17)
                        .textColor(Palette.text)
                }

        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("`text` and `formattedText` are MUTUALLY EXCLUSIVE, and that is MAUI's rule "
                + "rather than one made here: assigning FormattedText puts Text back to null. "
                + "The label above was given both.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The Swift type is `TextSpan`, not `Span`: Swift's own standard library has "
                + "a `Span` in scope in every file, and it wins - `Span(\"…\")` does not "
                + "compile. The node on the wire is still `Span`, which is MAUI's class name.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
