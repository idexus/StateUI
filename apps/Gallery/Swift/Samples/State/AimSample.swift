import StateUI

/// The other half of the doctrine: an author holds a CONTROL as well as
/// values, and declares it with `@Aim`. On a value you write; on a control you
/// call - and which member is which was decided by MAUI, not here.
struct AimSample: SampleContent {
    @State private var text = ""

    /// The control an act is about. `.aim` puts the element's own identity in
    /// here as the differ walks, so nothing is named and nothing collides.
    @Aim(Entry.self) private var field

    /// A second one, to show that two of them are two controls - and that an
    /// act aims at exactly the view it was put on.
    @Aim(Entry.self) private var note

    /// What the last act did. Written by the HANDLER rather than read in the
    /// body: the differ fills an aim as it WALKS, which is after the body that
    /// reads it was built.
    @State private var says = "Press a button, and it says which view it reached."

    static let id = "aim"
    static let title = "Aiming an act"
    static let summary = "A value you write, or a control you call - @State and @Aim."

    static let code = """
        // A VALUE: the modifier shows it, and writing it changes the control.
        @State private var text = ""

        // A CONTROL: .aim puts this view's identity in the aim, and the acts
        // MAUI declares as METHODS are what it offers.
        @Aim(Entry.self) private var field
        @Aim(Entry.self) private var note
        @State private var says = "Press a button, and it says which view it reached."

        VStack {
            // `says` is written by the handlers and read here, so this is the
            // closure a press rebuilds. The two fields are handed a binding
            // and an aim, neither of which reads anything.
            DebugInfoLabel()

            Entry($text)
                .placeholder("The first field")
                .aim(field)

            Entry()
                .placeholder("The second field")
                .aim(note)

            HStack {
                // Printing an aim says where it is: the element identity the
                // differ settled - "#12" - or the name an .id() gave it. Read
                // in the HANDLER, because the walk fills it after the body
                // that describes the view was built.
                Button("Focus the first")
                    .onClicked {
                        try await field.focus()
                        says = "focused \\(field)"
                    }

                Button("Focus the second")
                    .onClicked {
                        try await note.focus()
                        says = "focused \\(note)"
                    }

                Button("Let go")
                    .onClicked {
                        try await field.unfocus()
                        says = "let go of \\(field)"
                    }
            }

            Label(says)
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Entry($text)
                .automationId("aim.first")
                .semanticDescription("The first field")
                .placeholder("The first field")
                .aim(field)

            Entry()
                .automationId("aim.second")
                .semanticDescription("The second field")
                .placeholder("The second field")
                .aim(note)

            HStack {
                Button("Focus the first")
                    .backgroundColor(Palette.accent)
                    .cornerRadius(8)
                    .padding(14, 8)
                    .onClicked {
                        try await field.focus()
                        says = "focused \(field)"
                    }

                Button("Focus the second")
                    .backgroundColor(Palette.accent)
                    .cornerRadius(8)
                    .padding(14, 8)
                    .onClicked {
                        try await note.focus()
                        says = "focused \(note)"
                    }

                Button("Let go")
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .backgroundColor(.transparent)
                    .textColor(Palette.subtle)
                    .cornerRadius(8)
                    .padding(14, 8)
                    .onClicked {
                        try await field.unfocus()
                        says = "let go of \(field)"
                    }
            }
            .spacing(10)

            Label(says)
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("What an author holds is declared, one way for each kind. A VALUE is "
                + "@State, which the modifier that shows it also animates through its $ "
                + "binding. A CONTROL is @Aim: `.aim(field)` puts the view's address into "
                + "the aim, and on the aim you CALL what MAUI made a method - `focus()`, "
                + "`unfocus()`, a WebView's `goBack()`, a Map's `moveToRegion(_:)`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("What MAUI made a settable property is a MODIFIER here instead - opacity, "
                + "rotation, a Border's background - with a binding and an animation of that "
                + "binding. Nothing is both, so the one you want is the one MAUI declares - "
                + "with one exception: a scroller's offset is state here, "
                + "`.scroll($offset)`, where MAUI has a method.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("No names are involved: an aim points at the view it was put on, so two "
                + "instances of one composed view reach their own controls, and a view handed "
                + "its parent's aim reaches the parent's. Calling an act on an aim that is on "
                + "no view throws before anything is sent, and an aim put on two views at "
                + "once says so.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Read an aim from a HANDLER, not from a body: it is filled while the view "
                + "is drawn, so a body sees what the last render left, and `nowhere` on the "
                + "very first.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
