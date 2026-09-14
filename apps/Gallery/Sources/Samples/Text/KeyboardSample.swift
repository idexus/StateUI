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
        @State private var note = ""
        @State private var said = ""
        @Aim(Entry.self) private var first

        VStack {
            // `said` is read here, so the answer below builds this closure.
            DebugInfoLabel()

            Entry($name)
                .placeholder("Name")
                .aim(first)

            Entry($note)
                .placeholder("Note")

            HStack {
                Button("Focus first")
                    .onClicked { try await first.focus() }

                Button("Unfocus first")
                    .onClicked { try await first.unfocus() }
            }

            Button("Close keyboard")
                .onClicked {
                    said = try await SoftInput.hide()
                        ? "Focus released"
                        : "Nothing was focused"
                }

            Label(said.isEmpty ? "Nothing said yet." : said)
        }
        """

    var notes: Element? {
        Label("`focus()` and `unfocus()` are acts aimed at one field with `@Aim`. "
            + "`SoftInput.hide()` releases whichever input holds the focus, and answers "
            + "whether anything did.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }

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
                    .horizontalAlignment(.fill)
                    .onClicked { try await first.focus() }

                Button("Unfocus first")
                    .horizontalAlignment(.fill)
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
