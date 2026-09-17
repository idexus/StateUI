import StateUI

/// Runs of text inside one Label, each with a look of its own.
struct TextSpanSample: SampleContent, ExampleContent {
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
            // The chosen run is read here, so tapping one builds this closure.
            DebugInfoLabel()

            // Two colours in one line, which is what runs are FOR: a label
            // has one `textColor`, so this is the only way.
            Label()
                .spans {
                    TextSpan("let ").textColor(Palette.brand)
                    TextSpan("counter").textColor(Palette.accent)
                    TextSpan(" = 0")
                }

            // A run carries font properties of its own, and what an unset one
            // falls back to is the platform's business.
            Label()
                .spans {
                    TextSpan("Sold ")
                    TextSpan("out")
                        .fontAttributes(.bold)
                        .textColor(Palette.onAccent)
                        .background(Palette.accent)
                }

            // A loop is the usual way - one run per token, which is how the
            // code block on every page of this gallery is drawn.
            Label()
                .spans {
                    ForEach(Array(words.enumerated()), id: \\.offset) { pair in
                        let (index, word) = pair
                        return TextSpan(word + " ")
                            .textColor(index == highlighted ? Palette.accent : Palette.text)
                            .fontAttributes(index == highlighted ? .bold : .none)
                    }
                }

            Button("Move the highlight")
                .onClicked { highlighted = (highlighted + 1) % words.count }

            // `text` and `spans` are MUTUALLY EXCLUSIVE: a label
            // given both shows the runs.
            Label("this text never appears")
                .spans {
                    TextSpan("the runs win")
                }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label()
                .spans {
                    TextSpan("let ").textColor(Palette.brand)
                    TextSpan("counter").textColor(Palette.accent)
                    TextSpan(" = 0")
                }
                .fontSize(17)
                .fontFamily("Menlo")

            Label()
                .spans {
                    TextSpan("Sold ")
                        .fontSize(17)
                        .textColor(Palette.text)

                    TextSpan("out")
                        .fontSize(17)
                        .fontAttributes(.bold)
                        .textColor(Palette.onAccent)
                        .background(Palette.accent)
                }

            Label()
                .spans {
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

            Label("this text never appears")
                .spans {
                    TextSpan("the runs win")
                        .fontSize(17)
                        .textColor(Palette.text)
                }

        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Two colours in one line is what runs are for: a label has one `textColor`, "
                + "so text in two colours is two runs. A run carries font and text properties "
                + "of its own - size, family, weight, a background behind those words alone. "
                + "It is not a view, so there is no margin and no size on it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A loop is the usual way, one run per token - which is how the code block "
                + "under every example here is drawn. Moving the highlight sends the two runs "
                + "that changed and nothing else; the host keeps the rest of the line, the "
                + "same way it keeps a list of rows.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`text` and `spans` are MUTUALLY EXCLUSIVE: the last label is given "
                + "both, and it shows only the runs.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The Swift type is `TextSpan`, not `Span`: Swift's own standard library has "
                + "a `Span` in scope in every file, and it wins - `Span(\"…\")` does not "
                + "compile.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
