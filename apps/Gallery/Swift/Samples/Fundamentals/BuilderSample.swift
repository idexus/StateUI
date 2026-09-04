import StateUI

/// `if`, `if/else` and `ForEach` inside a builder - and what stays put across them.
struct BuilderSample: SampleContent {
    @State private var signedIn = false
    @State private var note = ""
    @State private var editing = false
    @State private var chosen = 2

    static let id = "builder"
    static let title = "Conditions and loops"
    static let summary = "if, if/else and ForEach inside a builder - and what keeps its control across them."

    static let code = """
        @State private var signedIn = false
        @State private var note = ""
        @State private var editing = false
        @State private var chosen = 2

        VStack {
            Switch($signedIn)

            // An `if` with no `else`. The Entry below it is child 0 in one
            // state and child 1 in the other - and it is the same control
            // either way, so what has been typed in it survives the toggle.
            if signedIn {
                Label("Signed in")
            }

            Entry($note)

            // Two branches are two elements, even though both are Entries:
            // switching REPLACES the control rather than editing it, which is
            // what the author wrote.
            if editing {
                Entry("name")
            } else {
                Entry("nickname")
            }

            SwitchRow("Editing", $editing)

            // A ForEach whose row changes its KIND with the choice. The
            // row's identity is its ITEM, so moving the choice touches two
            // rows - each replaced for its new kind - and leaves the other
            // three alone.
            ForEach(0..<5) { turn in
                if turn == chosen {
                    return Label("turn \\(turn) - chosen")
                } else {
                    return Button("turn \\(turn)")
                        .onClicked { chosen = turn }
                }
            }
        }
        """

    var example: Element {
        VStack {
            HStack {
                Switch($signedIn)

                Label("Signed in")
                    .verticalOptions(.center)
            }
            .spacing(12)

            if signedIn {
                Label("Signed in")
                    .fontAttributes(.bold)
            }

            Entry($note)
                .placeholder("Type here, then flip the switch")

            Label("What you typed is still here: an `if` above a view no longer "
                + "moves it, so the Entry keeps its control - and with it the text, "
                + "the caret and the focus.")
                .fontSize(12)
                .textColor(Palette.subtle)

            if editing {
                Entry("name")
                    .placeholder("name")
            } else {
                Entry("nickname")
                    .placeholder("nickname")
            }

            SwitchRow("Editing", $editing)
                .horizontalOptions(.start)

            Label("Both branches build an Entry, and they are still two different "
                + "elements: swapping replaces the control rather than editing it, "
                + "which is what the two branches say.")
                .fontSize(12)
                .textColor(Palette.subtle)

            ForEach(0..<5) { turn in
                if turn == chosen {
                    return Label("turn \(turn) - chosen")
                        .fontAttributes(.bold)
                        .textColor(Palette.accent)
                } else {
                    return Button("turn \(turn)")
                        .fontSize(13)
                        .padding(16, 6)
                        .horizontalOptions(.start)
                        .onClicked { chosen = turn }
                }
            }

        }
        .spacing(12)
    }

    var notes: Element? {
        Label("Five rows out of one ForEach, each choosing what to build. Moving "
            + "the choice sends two changes, not five: a row is identified by its "
            + "ITEM, whatever the rows around it decide.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
