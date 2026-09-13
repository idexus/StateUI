import StateUI

/// MAUI: Entry.
struct EntrySample: SampleContent {
    @State private var name = ""
    @State private var editing = false
    @State private var code = ""
    @State private var selectAll = false
    @State private var email = ""
    @State private var done = 0

    static let id = "entry"
    static let title = "Entry"
    static let summary = "A single-line field. Given a binding it writes every edit back."

    static let code = """
        @State private var name = ""
        @State private var editing = false
        @State private var code = ""
        @State private var selectAll = false
        @State private var email = ""
        @State private var done = 0

        VStack {
            // The greeting below reads `name` and the caret below reads `code`,
            // so a keystroke in either builds this closure; the fields read
            // nothing - they are handed the state - and typing an address or a
            // password builds nothing at all.
            DebugInfoLabel()

            Entry($name)
                .placeholder("Type your name")
                .clearButtonVisibility(.whileEditing)
                .isFocused($editing)

            Label(name.isEmpty ? "Hello, stranger" : "Hello, \\(name)!")

            Label(editing ? "the field has the focus" : "the field does not have the focus")

            Label("return pressed \\(done)x")

            // A field for something that is not prose: the platform's
            // underline and its next-word guesses only get in the way, and the
            // caret can be put where the reader did not.
            Entry($code)
                .placeholder("a serial number")
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

            Entry("read only")
                .isReadOnly(true)

            Entry()
                .placeholder("a password")
                .isPassword(true)
                .returnType(.done)

            // The keyboard the platform brings up, a cap on the length, and
            // what the return key does when it is pressed.
            Entry($email)
                .placeholder("an address, capped at 20")
                .keyboard(.email)
                .maxLength(20)
                .onCompleted { done += 1 }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Entry($name)
                .automationId("entry.name")
                .semanticDescription("Name")
                .placeholder("Type your name")
                .clearButtonVisibility(.whileEditing)
                .isFocused($editing)

            Label(name.isEmpty ? "Hello, stranger" : "Hello, \(name)!")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Label(editing ? "the field has the focus" : "the field does not have the focus")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Label("return pressed \(done)x")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            // A field for something that is not prose: the platform's
            // underline and its next-word guesses only get in the way, and
            // the caret can be put where the reader did not.
            Entry($code)
                .automationId("entry.code")
                .semanticDescription("Serial number")
                .placeholder("a serial number")
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
                .horizontalOptions(.center)
                .onClicked { selectAll.toggle() }

            Entry("read only")
                .automationId("entry.readOnly")
                .semanticDescription("A field that cannot be typed in")
                .isReadOnly(true)

            Entry()
                .automationId("entry.password")
                .semanticDescription("Password")
                .placeholder("a password")
                .isPassword(true)
                .returnType(.done)

            // The keyboard the platform brings up, a cap on the length, and
            // what the return key does when it is pressed.
            Entry($email)
                .automationId("entry.email")
                .semanticDescription("Email address")
                .placeholder("an address, capped at 20")
                .keyboard(.email)
                .maxLength(20)
                .onCompleted { done += 1 }
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("The binding IS the two-way part: `Entry($name)` hands the state to the "
            + "host, which shows it in the field and lands every edit back on it. "
            + "`.onTextChanged` written afterwards runs beside it, never instead of "
            + "it, and after the state already holds the text.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
