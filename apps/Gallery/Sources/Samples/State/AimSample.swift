import StateUI

/// An author holds a CONTROL as well as values, and declares it with `@Aim`:
/// on a value you write, on a control you call.
struct AimSample: SampleContent, ExampleContent {
    // listing: AimSample
    @State private var text = ""

    /// What the second field holds.
    @State private var second = ""

    /// The control an act is about. `.aim` puts the element's own identity in
    /// here as the differ walks, so nothing is named and nothing collides.
    @Aim(TextField.self) private var field

    /// A second one, to show that two of them are two controls - and that an
    /// act aims at exactly the view it was put on.
    @Aim(TextField.self) private var note

    /// What the last act did, written by the handler that reads the aim: the
    /// differ fills an aim as it WALKS, which is after the body that would read
    /// it was built.
    @State private var says = "Press a button, and it says which view it reached."

    /// Whether the first aim is on the second field too - on two views, which
    /// an act aimed through it refuses, until it is on one again.
    @State private var both = false
    // listing: end

    static let id = "aim"
    static let title = "Aiming an act"
    static let summary = "A value you write, or a control you call - @State and @Aim."

    static var code: String { Listings.joined("AimedField", "AimSample") }

    // listing: AimSample
    var body: some View {
        VStack {
            // `says` is written by the handlers and read here, so this is the
            // closure a press rebuilds. The two fields are handed a binding
            // and an aim, neither of which reads anything.
            DebugInfoLabel()

            // The first field is a view of its own, handed the aim and the text:
            // nothing it holds changes as this page builds again, so it is
            // carried - and keeps the aim on its field all the same.
            AimedField(aim: field, text: $text)

            TextField($second)
                .accessibilityIdentifier("aim.second")
                .accessibilityLabel("The second field")
                .placeholder("The second field")
                .aim(both ? field : note)

            Switch("The first aim on the second field too", isOn: $both)
                .accessibilityIdentifier("aim.both")

            HStack {
                // Printing an aim says where it is: the element identity the
                // differ settled - "#12" - or the name an .id() gave it. Read
                // in the HANDLER, because the walk fills it after the body
                // that describes the view was built. On two views, the act
                // throws before anything is sent.
                Button("Focus the first")
                    .onClicked(policy: .ignoreWhileRunning) {
                        do {
                            try await field.focus()
                            says = "focused \(field)"
                        } catch {
                            says = "\(error)"
                        }
                    }

                Button("Focus the second")
                    .onClicked(policy: .ignoreWhileRunning) {
                        try await note.focus()
                        says = "focused \(note)"
                    }
            }
            .spacing(10)

            // Each aim reaches its own field: letting go of both is two acts.
            Button("Let go")
                .onClicked(policy: .ignoreWhileRunning) {
                    try await field.unfocus()
                    try await note.unfocus()
                    says = "let go of \(field) and \(note)"
                }

            Text(says)
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Put the first aim on the second field too: focusing the first says the aim is on two views. "
                + "Take it off again, and the first field - carried all along - is the aim's once more.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("What an author holds is declared, one way for each kind. A value is "
                + "@State, which the modifier that shows it also animates through its $ "
                + "binding. A control is @Aim: `.aim(field)` puts the view's address into "
                + "the aim, and on the aim you call the control's methods - `focus()`, "
                + "`unfocus()`, a WebView's `goBack()`, a Map's `show(_:)`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A property is a modifier - opacity, rotation, a stack's background - "
                + "which takes a binding and animates along that binding's journey. Nothing "
                + "is both a modifier and a method, and a scroller's offset is state as "
                + "well: `.scrollOffset($offset)`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("No names are involved: an aim points at the view it was put on, so two "
                + "instances of one composed view reach their own controls, and a view handed "
                + "its parent's aim reaches the parent's. Calling an act on an aim that is on "
                + "no view throws before anything is sent, and an aim put on two views at "
                + "once says so.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Read an aim from a handler, not from a body: it is filled as the view is "
                + "walked, after its body is built, so a body sees what the last render "
                + "left, and `nowhere` on the very first.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

// listing: AimedField
/// The first field: handed the page's aim and its text, so the page building
/// again carries it - and the aim stays on the field it was put on.
private struct AimedField: View {
    let aim: Aim<TextField>
    @Binding var text: String

    var body: some View {
        TextField($text)
            .accessibilityIdentifier("aim.first")
            .accessibilityLabel("The first field")
            .placeholder("The first field")
            .aim(aim)
    }
}
// listing: end
