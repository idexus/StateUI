import StateUI

/// Explicit native focus and soft-input actions.
struct KeyboardSample: SampleContent, ExampleContent {
    // listing: KeyboardSample
    @State private var name = ""
    @State private var note = ""
    @State private var said = ""

    @Aim(TextField.self) private var first
    // listing: end

    static let id = "keyboard"
    static let title = "Keyboard"
    static let summary = "Aim at one field, or release whichever input is focused."

    var notes: (any View)? {
        Text("`focus()` and `unfocus()` are acts aimed at one field with `@Aim`. "
            + "`OnScreenKeyboard.hide()` releases whichever input holds the focus, and answers "
            + "whether anything did.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }

    // listing: KeyboardSample
    var body: some View {
        VStack {
            // `said` is read here, so the answer below builds this closure.
            DebugInfoLabel()

            TextField($name)
                .accessibilityIdentifier("keyboard.name")
                .accessibilityLabel("Name")
                .placeholder("Name")
                .aim(first)

            TextField($note)
                .accessibilityIdentifier("keyboard.note")
                .accessibilityLabel("Note")
                .placeholder("Note")

            HStack {
                Button("Focus first")
                    .horizontalAlignment(.fill)
                    .onClicked(gate: .ignoreWhileRunning) { try await first.focus() }

                Button("Unfocus first")
                    .horizontalAlignment(.fill)
                    .onClicked(gate: .ignoreWhileRunning) { try await first.unfocus() }
            }
            .spacing(8)

            Button("Close keyboard")
                .onClicked(gate: .ignoreWhileRunning) {
                    said = try await OnScreenKeyboard.hide()
                        ? "Focus released"
                        : "Nothing was focused"
                }

            Text(said.isEmpty ? "Nothing said yet." : said)
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
    // listing: end
}
