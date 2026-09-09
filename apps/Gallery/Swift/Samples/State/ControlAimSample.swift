import StateUI

/// The other half of the doctrine: a piece of state can hold a CONTROL. On a
/// value you write; on a control you call - and which member is which was
/// decided by MAUI, not here.
struct ControlAimSample: SampleContent {
    @State private var text = ""

    /// The control an act is about. `.assign` puts the element's own identity
    /// in here as the differ walks, so nothing is named and nothing collides.
    @State private var field = ControlAim<Entry>()

    /// A second one, to show that two of them are two controls - and that an
    /// act aims at exactly the view it was assigned to.
    @State private var note = ControlAim<Entry>()

    /// What the last act did. Written by the HANDLER rather than read in the
    /// body: the differ fills an aim as it WALKS, which is after the
    /// body that reads it was built.
    @State private var says = "Press a button, and it says which view it reached."

    static let id = "control-aim"
    static let title = "Aiming an act"
    static let summary = "A value you write, or a control you call - both are @State."

    static let code = """
        // A VALUE: the modifier shows it, and writing it changes the control.
        @State private var text = ""

        // A CONTROL: .assign puts this view's identity in the state, and the
        // acts MAUI declares as METHODS are what it offers.
        @State private var field = ControlAim<Entry>()
        @State private var note = ControlAim<Entry>()
        @State private var says = "Press a button, and it says which view it reached."

        VStack {
            // `says` is written by the handlers and read here, so this is the
            // closure a press rebuilds. The two fields are handed bindings and
            // aims, neither of which reads anything.
            DebugInfoLabel()

            Entry($text)
                .placeholder("The first field")
                .assign(to: field)

            Entry()
                .placeholder("The second field")
                .assign(to: note)

            HStack {
                // Printing an aim says what it is assigned to: the
                // element identity the differ settled - "#12" - or the name an
                // .id() gave it. Read in the HANDLER, because the walk fills it
                // after the body that describes the view was built.
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

    var content: Element {
        VStack {
            DebugInfoLabel()

            Entry($text)
                .placeholder("The first field")
                .assign(to: field)

            Entry()
                .placeholder("The second field")
                .assign(to: note)

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
            Label("Everything an author holds is @State, and there are two kinds. A VALUE, "
                + "which the modifier that shows it also animates through its $ binding. Or "
                + "a CONTROL: `.assign(to: state)` puts the view's address into state, and on "
                + "that state you CALL what MAUI made a method - `focus()`, `unfocus()`, "
                + "a WebView's `goBack()`, a Map's `moveToRegion(_:)`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("What MAUI made a settable property is a MODIFIER here instead - opacity, "
                + "rotation, a Border's background - with a binding and an animation of that "
                + "binding. Nothing is both, so the one you want is the one MAUI declares.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("No names are involved: an aim points at the view that assigned it, "
                + "so two instances of one composed view reach their own controls. Calling "
                + "an act on an aim nothing was assigned to throws before anything is sent, "
                + "and an aim assigned to two views at once says so.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Read an aim from a HANDLER, not from a body: it is filled while "
                + "the view is drawn, so a body sees what the last render left and "
                + "`unassigned` on the very first.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
