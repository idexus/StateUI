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
            Editor($notes)
                .placeholder("Anything worth remembering")
                .heightRequest(110)

            Label(notes.isEmpty ? "nothing written yet" : "\\(notes.count) character(s)")

            Button("Clear")
                .isEnabled(!notes.isEmpty)
                .onClicked { notes = "" }
        }

        // .autoSize(.textChanges) grows the box with the text instead.
        """

    var content: Element {
        VStack {
            Editor($notes)
                .placeholder("Anything worth remembering")
                .heightRequest(110)

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
