import StateUI

/// The other half of the doctrine: a piece of state can hold a CONTROL. On a
/// value you write; on a control you call - and which member is which was
/// decided by MAUI, not here.
struct ControlStateSample: SampleContent {
    @State private var text = ""

    /// The control an act is about. `.assign` puts the element's own identity
    /// in here as the differ walks, so nothing is named and nothing collides.
    @State private var field = ControlState<Entry>()

    /// A second one, to show that two of them are two controls - and that an
    /// act aims at exactly the view it was assigned to.
    @State private var note = ControlState<Entry>()

    /// What the last act did. Written by the HANDLER rather than read in the
    /// body: the differ fills a control state as it WALKS, which is after the
    /// body that reads it was built.
    @State private var says = "Press a button, and it says which view it reached."

    static let id = "control-state"
    static let title = "A control in state"
    static let summary = "A value you write, or a control you call - both are @State."

    static let code = """
        @State private var text = ""

        // A VALUE: the modifier shows it, and writing it changes the control.
        Entry($text).placeholder("Type here")

        // A CONTROL: .assign puts this view's identity in the state, and the
        // acts MAUI declares as METHODS are what it offers.
        @State private var field = ControlState<Entry>()
        @State private var note = ControlState<Entry>()
        @State private var says = "Press a button, and it says which view it reached."

        VStack {
            Entry($text)
                .placeholder("The first field")
                .assign(field)

            Entry()
                .placeholder("The second field")
                .assign(note)

            HStack {
                // Printing a control state says what it is assigned to: the
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
            Entry($text)
                .placeholder("The first field")
                .assign(field)

            Entry()
                .placeholder("The second field")
                .assign(note)

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
            Label("Everything an author holds is @State, and there are two kinds. A "
                + "VALUE, which the modifier that shows it also animates through its $ "
                + "binding. Or a CONTROL, whose address .assign puts into state - and on "
                + "that control you CALL what MAUI made a method.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The split is not this library's taste. MAUI made it per member, and "
                + "copying it is what keeps \"the API is MAUI's\" true of the SHAPE and "
                + "not only of the names: IsFocused is read-only in MAUI and ScrollX has "
                + "a private setter, so focusing and scrolling are methods there and acts "
                + "here. Where MAUI declares a settable BindableProperty - Opacity, "
                + "Rotation, a Border's background - this library gives you a modifier, a "
                + "binding, and an animation of that binding. Nothing is both.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("There is no name in any of it. The differ gives every element an "
                + "identity - allocated once, never reused, stable for as long as the "
                + "element stays in the tree - and .assign is how a view hands it over; "
                + "printing the state shows exactly that, \"#12\" for a view nobody "
                + "named. Two instances of one composed view therefore aim at their own "
                + "controls, which a string id could never promise. An act on a state "
                + "that was never assigned throws before anything is sent, and one "
                + "assigned to two views at once says so.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The reading above is written by the HANDLER, and that is worth "
                + "knowing: the differ fills a control state as it WALKS, which happens "
                + "after the body that describes the view was built. So a body that "
                + "printed one would show what the last render settled, and \"unassigned\" "
                + "on the very first - while a handler runs between renders and sees the "
                + "identity the view actually has.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
