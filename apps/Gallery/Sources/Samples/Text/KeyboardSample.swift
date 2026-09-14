import StateUI

/// Explicit native focus and soft-input actions.
struct KeyboardSample: SampleContent, ExampleContent {
    @State private var name = ""
    @State private var note = ""
    @State private var said = ""

    @Aim(Entry.self) private var first

    static let id = "keyboard"
    static let title = "Keyboard"
    static let summary = "Aim at one field, or release whichever input is focused."

    static let code = """
        @State private var name = ""
        @Aim(Entry.self) private var nameField

        DebugInfoLabel()

        Entry($name)
            .aim(nameField)

        Button("Focus")
            .onClicked { try await nameField.focus() }

        Button("Unfocus")
            .onClicked { try await nameField.unfocus() }

        Button("Close keyboard")
            .onClicked { try await SoftInput.hide() }
        """

    var notes: Element? { nil }

    var content: any View {
        VStack {
            DebugInfoLabel()

            Entry($name)
                .automationId("keyboard.name")
                .semanticDescription("Name")
                .placeholder("Name")
                .aim(first)

            Entry($note)
                .automationId("keyboard.note")
                .semanticDescription("Note")
                .placeholder("Note")

            HStack {
                Button("Focus first")
                    .horizontalOptions(.fill)
                    .onClicked { try await first.focus() }

                Button("Unfocus first")
                    .horizontalOptions(.fill)
                    .onClicked { try await first.unfocus() }
            }
            .spacing(8)

            Button("Close keyboard")
                .onClicked {
                    said = try await SoftInput.hide()
                        ? "Focus released"
                        : "Nothing was focused"
                }

            Label(said.isEmpty ? "Nothing said yet." : said)
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
