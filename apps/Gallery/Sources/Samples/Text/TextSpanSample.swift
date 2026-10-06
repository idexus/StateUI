import StateUI

/// Runs of text inside one Text, each with a look of its own.
struct TextSpanSample: SampleContent, ExampleContent {
    // listing: TextSpanSample
    @State private var highlighted = 1

    /// The line the last example colours one word of.
    private let words = ["A", "Text", "has", "one", "TextColor"]
    // listing: end

    static let id = "textSpan"
    static let title = "TextSpan"
    static let summary = "Text in more than one colour: a Text's runs, each with a look of its own."

    // listing: TextSpanSample
    var body: some View {
        VStack {
            // The chosen run is read here, so tapping one builds this closure.
            DebugInfoLabel()

            // Two colours in one line, which is what runs are FOR: a label
            // has one `textColor`, so this is the only way.
            Text()
                .spans {
                    TextSpan("let ").textColor(Palette.brand)
                    TextSpan("counter").textColor(Palette.accent)
                    TextSpan(" = 0")
                }
                .fontSize(17)
                .fontFamily("Menlo")

            Text()
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

            Text()
                .spans {
                    words.enumerated().map { index, word in
                        TextSpan(word + " ")
                            .fontSize(17)
                            .textColor(index == highlighted ? Palette.accent : Palette.text)
                            .fontAttributes(index == highlighted ? .bold : .none)
                    }
                }

            Button("Move the highlight")
                .onClicked { highlighted = (highlighted + 1) % words.count }

            // `text` and `spans` are MUTUALLY EXCLUSIVE: a label
            // given both shows the runs.
            Text("this text never appears")
                .spans {
                    TextSpan("the runs win")
                        .fontSize(17)
                        .textColor(Palette.text)
                }

        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Two colours in one line is what runs are for: a label has one `textColor`, "
                + "so text in two colours is two runs. A run carries font and text properties "
                + "of its own - size, family, weight, a background behind those words alone. "
                + "It is not a view, so there is no margin and no size on it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A list is the usual way, one run per token - which is how the code block "
                + "under every example here is drawn. Moving the highlight sends the two runs "
                + "that changed and nothing else; the host keeps the rest of the line, the "
                + "same way it keeps a list of rows.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`text` and `spans` are MUTUALLY EXCLUSIVE: the last label is given "
                + "both, and it shows only the runs.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The Swift type is `TextSpan`, not `TextSpan`: Swift's own standard library has "
                + "a `TextSpan` in scope in every file, and it wins - `TextSpan(\"…\")` does not "
                + "compile.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
