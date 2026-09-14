import StateUI

/// Text of several lines, in an editor of a stated height and one that grows.
struct TextEditorSample: SampleContent, ExampleContent {
    @State private var draft = ""

    static let id = "textEditor"
    static let title = "TextEditor"
    static let summary = "A TextField with room: several lines, and a size that can follow the text."

    static let code = """
        @State private var draft = ""

        VStack {
            // The count of characters below reads `draft`, so every keystroke
            // builds this closure; the two editors are handed the state.
            DebugInfoLabel()

            // The same text in both editors: the left keeps its stated
            // height, the right grows with every line you add.
            Grid {
                VStack {
                    Label("a stated height")

                    TextEditor($draft)
                        .placeholder("Anything worth remembering")
                        .height(110)
                }

                VStack {
                    Label(".growsWithText(true)")

                    TextEditor($draft)
                        .placeholder("The same text, sized by it")
                        .growsWithText(true)
                }
                .gridColumn(1)
            }
            .columns(.fill, .fill)

            Label(draft.isEmpty ? "nothing written yet" : "\\(draft.count) character(s)")

            Button("Clear")
                .isEnabled(!draft.isEmpty)
                .onClicked { draft = "" }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            // The same text in both editors, so typing in either moves the
            // other - and only the right one grows with it.
            Grid {
                VStack {
                    Label("a stated height")
                        .fontSize(12)
                        .textColor(Palette.subtle)

                    TextEditor($draft)
                        .accessibilityIdentifier("editor.notes")
                        .accessibilityLabel("Notes")
                        .placeholder("Anything worth remembering")
                        .height(110)
                }
                .spacing(4)

                VStack {
                    Label(".growsWithText(true)")
                        .fontSize(12)
                        .textColor(Palette.subtle)

                    TextEditor($draft)
                        .accessibilityIdentifier("editor.notes.growsWithText")
                        .accessibilityLabel("Notes, sized by the text")
                        .placeholder("The same text, sized by it")
                        .growsWithText(true)
                }
                .spacing(4)
                .verticalAlignment(.start)
                .gridColumn(1)
            }
            .columns(.fill, .fill)
            .columnSpacing(12)

            Label(draft.isEmpty ? "nothing written yet" : "\(draft.count) character(s)")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Button("Clear")
                .fontSize(13)
                .padding(16, 6)
                .horizontalAlignment(.center)
                .isEnabled(!draft.isEmpty)
                .onClicked { draft = "" }
        }
        .spacing(12)
    }

    var notes: Element? { nil }
}
