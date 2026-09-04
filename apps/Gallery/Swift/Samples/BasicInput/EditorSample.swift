import StateUI

/// MAUI: Editor.
struct EditorSample: SampleContent {
    @State private var notes = ""

    static let id = "editor"
    static let title = "Editor"
    static let summary = "An Entry with room: several lines, and a size that can follow the text."

    static let code = """
        @State private var notes = ""

        VStack {
            // The same text in both editors: the left keeps its stated
            // height, the right grows with every line you add.
            Grid {
                VStack {
                    Label("a stated height")

                    Editor($notes)
                        .placeholder("Anything worth remembering")
                        .heightRequest(110)
                }

                VStack {
                    Label(".autoSize(.textChanges)")

                    Editor($notes)
                        .placeholder("The same text, sized by it")
                        .autoSize(.textChanges)
                }
                .gridColumn(1)
            }
            .columnDefinitions(.star, .star)

            Label(notes.isEmpty ? "nothing written yet" : "\\(notes.count) character(s)")

            Button("Clear")
                .isEnabled(!notes.isEmpty)
                .onClicked { notes = "" }
        }
        """

    var example: Element {
        VStack {
            // The same text in both editors, so typing in either moves the
            // other - and only the right one grows with it.
            Grid {
                VStack {
                    Label("a stated height")
                        .fontSize(12)
                        .textColor(Palette.subtle)

                    Editor($notes)
                        .placeholder("Anything worth remembering")
                        .heightRequest(110)
                }
                .spacing(4)

                VStack {
                    Label(".autoSize(.textChanges)")
                        .fontSize(12)
                        .textColor(Palette.subtle)

                    Editor($notes)
                        .placeholder("The same text, sized by it")
                        .autoSize(.textChanges)
                }
                .spacing(4)
                .verticalOptions(.start)
                .gridColumn(1)
            }
            .columnDefinitions(.star, .star)
            .columnSpacing(12)

            Label(notes.isEmpty ? "nothing written yet" : "\(notes.count) character(s)")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Button("Clear")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .isEnabled(!notes.isEmpty)
                .onClicked { notes = "" }
        }
        .spacing(12)
    }
}
