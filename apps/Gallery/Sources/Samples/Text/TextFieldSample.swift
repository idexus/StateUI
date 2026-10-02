import StateUI

/// Single-line text fields, with focus, caret, selection and keyboard choices.
struct TextFieldSample: SampleContent, ExampleContent {
    @State private var name = ""
    @State private var editing = false
    @State private var code = ""
    @State private var selectAll = false
    @State private var email = ""
    @State private var done = 0
    @State private var hidden = true

    static let id = "textField"
    static let title = "TextField"
    static let summary = "A single-line field. Given a binding it writes every edit back."

    static let code = """
        @State private var name = ""
        @State private var editing = false
        @State private var code = ""
        @State private var selectAll = false
        @State private var email = ""
        @State private var done = 0
        @State private var hidden = true

        VStack {
            // The greeting below reads `name` and the caret below reads `code`,
            // so a keystroke in either builds this closure; the fields read
            // nothing - they are handed the state - and typing an address or a
            // password builds nothing at all.
            DebugInfoLabel()

            TextField($name)
                .placeholder("Type your name")
                .showsClearButton(true)
                .isFocused($editing)

            Text(name.isEmpty ? "Hello, stranger" : "Hello, \\(name)!")

            Text(editing ? "the field has the focus" : "the field does not have the focus")

            Text("return pressed \\(done)x")

            // A field for something that is not prose: the platform's
            // underline and its next-word guesses only get in the way, the
            // caret can be put where the user did not, and every letter
            // typed stands in capitals, as a serial number's do.
            TextField($code)
                .placeholder("a serial number")
                .textCase(.uppercase)
                .isSpellCheckEnabled(false)
                .isTextPredictionEnabled(false)
                .cursorPosition(selectAll ? 0 : code.count)
                .selectionLength(selectAll ? code.count : 0)

            // SELECTING IS SOMETHING THAT HAPPENS, so it is a button rather
            // than a switch - and it says which of the two it will do next,
            // because a press has to WRITE a value the field has not been
            // given: an absent field means unchanged, so a press that asks
            // for the selection the field already has says nothing at all.
            Button(selectAll ? "Clear the selection" : "Select the lot")
                .onClicked { selectAll.toggle() }

            TextField("read only")
                .isReadOnly(true)

            TextField()
                .placeholder("a password")
                .isPassword(hidden)
                .returnKey(.done)

            HStack {
                Text("Hidden")
                    .verticalAlignment(.center)

                Switch($hidden)
            }

            // The keyboard the platform brings up, a cap on the length, and
            // what the return key does when it is pressed.
            TextField($email)
                .placeholder("an address, capped at 20")
                .inputPurpose(.email)
                .maximumLength(20)
                .onSubmitted { done += 1 }
        }
        """

    var body: some View {
        VStack {
            DebugInfoLabel()

            TextField($name)
                .accessibilityIdentifier("entry.name")
                .accessibilityLabel("Name")
                .placeholder("Type your name")
                .showsClearButton(true)
                .isFocused($editing)

            Text(name.isEmpty ? "Hello, stranger" : "Hello, \(name)!")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Text(editing ? "the field has the focus" : "the field does not have the focus")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Text("return pressed \(done)x")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            // A field for something that is not prose: the platform's
            // underline and its next-word guesses only get in the way, the
            // caret can be put where the user did not, and every letter
            // typed stands in capitals, as a serial number's do.
            TextField($code)
                .accessibilityIdentifier("entry.code")
                .accessibilityLabel("Serial number")
                .placeholder("a serial number")
                .textCase(.uppercase)
                .isSpellCheckEnabled(false)
                .isTextPredictionEnabled(false)
                .cursorPosition(selectAll ? 0 : code.count)
                .selectionLength(selectAll ? code.count : 0)

            // SELECTING IS SOMETHING THAT HAPPENS, so it is a button rather
            // than a switch - and it says which of the two it will do next,
            // because a press has to WRITE a value the field has not been
            // given: an absent field means unchanged, so a press that asks
            // for the selection the field already has says nothing at all.
            Button(selectAll ? "Clear the selection" : "Select the lot")
                .fontSize(13)
                .padding(16, 6)
                .horizontalAlignment(.center)
                .onClicked { selectAll.toggle() }

            TextField("read only")
                .accessibilityIdentifier("entry.readOnly")
                .accessibilityLabel("A field that cannot be typed in")
                .isReadOnly(true)

            TextField()
                .accessibilityIdentifier("entry.password")
                .accessibilityLabel("Password")
                .placeholder("a password")
                .isPassword(hidden)
                .returnKey(.done)

            HStack {
                Text("Hidden")
                    .fontSize(14)
                    .verticalAlignment(.center)

                Switch($hidden)
                    .accessibilityIdentifier("entry.hidden")
                    .accessibilityLabel("Password hidden")
            }
            .spacing(12)
            .horizontalAlignment(.center)

            // The keyboard the platform brings up, a cap on the length, and
            // what the return key does when it is pressed.
            TextField($email)
                .accessibilityIdentifier("entry.email")
                .accessibilityLabel("Email address")
                .placeholder("an address, capped at 20")
                .inputPurpose(.email)
                .maximumLength(20)
                .onSubmitted { done += 1 }
        }
        .spacing(12)
    }

    var notes: (any View)? {
        Text("The binding IS the two-way part: `TextField($name)` hands the state to the "
            + "host, which shows it in the field and lands every edit back on it. "
            + "`.onTextChanged` written afterwards runs beside it, never instead of "
            + "it, and after the state already holds the text.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
