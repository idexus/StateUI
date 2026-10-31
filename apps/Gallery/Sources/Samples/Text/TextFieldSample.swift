import StateUI

/// Single-line text fields, with focus, caret, selection and keyboard choices.
struct TextFieldSample: SampleContent, ExampleContent {
    // listing: TextFieldSample
    @State private var name = ""
    @State private var editing = false
    @State private var code = ""
    @State private var selectAll = false
    @State private var email = ""
    @State private var done = 0
    @State private var hidden = true
    @State private var user = ""
    @State private var newPassword = ""
    @State private var signInCode = ""
    @State private var outlined = ""
    // listing: end

    static let id = "textField"
    static let title = "TextField"
    static let summary = "A single-line field writing every edit back to its binding."

    // listing: TextFieldSample
    var body: some View {
        VStack {
            // The greeting below reads `name` and the caret below reads `code`,
            // so a keystroke in either builds this closure; the fields read
            // nothing - they are handed the state - and typing an address or a
            // password builds nothing at all.
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
            // given: a value the patch leaves out means unchanged, so a press
            // that asks for the selection the field already has says nothing.
            Button(selectAll ? "Clear the selection" : "Select the lot")
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
                .submitLabel(.done)

            Switch($hidden)
                .text("Hidden")
                .accessibilityIdentifier("entry.hidden")
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

            // Signing in: what each field holds is what the platform fills
            // it in with - a name it keeps, a strong password it makes and
            // keeps, a code it received.
            TextField($user)
                .accessibilityIdentifier("entry.username")
                .accessibilityLabel("User name")
                .placeholder("a user name")
                .inputPurpose(.username)

            TextField($newPassword)
                .accessibilityIdentifier("entry.newPassword")
                .accessibilityLabel("New password")
                .placeholder("a new password")
                .isPassword(true)
                .inputPurpose(.newPassword)

            TextField($signInCode)
                .accessibilityIdentifier("entry.signInCode")
                .accessibilityLabel("Sign-in code")
                .placeholder("a code sent to you")
                .inputPurpose(.oneTimeCode)

            // An outline of the application's own, in place of the
            // platform's frame, and the shape the field stands in.
            TextField($outlined)
                .accessibilityIdentifier("entry.outlined")
                .accessibilityLabel("Outlined")
                .placeholder("an outlined capsule")
                .stroke(Palette.accent)
                .lineWidth(1.5)
                .shape(.capsule)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("The binding IS the two-way part: `TextField($name)` hands the state to the "
            + "host, which shows it in the field and lands every edit back on it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
