import StateUI

/// Text of several lines, in an editor of a stated height and one that grows.
struct EditorSample: SampleContent, ExampleContent {
    @State private var draft = ""

    static let id = "editor"
    static let title = "Editor"
    static let summary = "An Entry with room: several lines, and a size that can follow the text."

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

                    Editor($draft)
                        .placeholder("Anything worth remembering")
                        .heightRequest(110)
                }

                VStack {
                    Label(".autoSize(.textChanges)")

                    Editor($draft)
                        .placeholder("The same text, sized by it")
                        .autoSize(.textChanges)
                }
                .gridColumn(1)
            }
            .columnDefinitions(.star, .star)

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

                    Editor($draft)
                        .automationId("editor.notes")
                        .semanticDescription("Notes")
                        .placeholder("Anything worth remembering")
                        .heightRequest(110)
                }
                .spacing(4)

                VStack {
                    Label(".autoSize(.textChanges)")
                        .fontSize(12)
                        .textColor(Palette.subtle)

                    Editor($draft)
                        .automationId("editor.notes.autoSize")
                        .semanticDescription("Notes, sized by the text")
                        .placeholder("The same text, sized by it")
                        .autoSize(.textChanges)
                }
                .spacing(4)
                .verticalOptions(.start)
                .gridColumn(1)
            }
            .columnDefinitions(.star, .star)
            .columnSpacing(12)

            Label(draft.isEmpty ? "nothing written yet" : "\(draft.count) character(s)")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Button("Clear")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .isEnabled(!draft.isEmpty)
                .onClicked { draft = "" }
        }
        .spacing(12)
    }

    var notes: Element? { nil }
}
