import StateUI

/// `if`, `if/else` and `ForEach` inside a builder - and what stays put across them.
struct BuilderSample: SampleContent, ExampleContent {
    // listing: BuilderSample
    @State private var signedIn = false
    @State private var note = ""
    @State private var editing = false
    @State private var chosen = 2
    // listing: end

    static let id = "builder"
    static let title = "Conditions and loops"
    static let summary = "if, if/else and ForEach inside a builder - and what keeps its control across them."

    // listing: BuilderSample
    var body: some View {
        VStack {
            // The conditions and the choice are all read here, so THIS is
            // the closure a flip or a pick builds again.
            DebugInfoLabel()

            HStack {
                Switch($signedIn)
                    .accessibilityIdentifier("builder.signedIn")
                    .accessibilityLabel("Signed in")

                Text("Signed in")
                    .verticalAlignment(.center)
            }
            .spacing(12)

            // An `if` with no `else`. The TextField below it is child 2 in one
            // state and child 3 in the other - and it is the same control
            // either way, so what has been typed in it survives the toggle.
            if signedIn {
                Text("Signed in")
                    .fontAttributes(.bold)
            }

            TextField($note)
                .accessibilityIdentifier("builder.note")
                .accessibilityLabel("Note")
                .placeholder("Type here, then flip the switch")

            // Two branches are two elements, even though both are TextFields:
            // switching REPLACES the control rather than editing it, which is
            // what the author wrote.
            if editing {
                TextField("name")
                    .accessibilityIdentifier("builder.name")
                    .accessibilityLabel("Name")
                    .placeholder("name")
            } else {
                TextField("nickname")
                    .accessibilityIdentifier("builder.nickname")
                    .accessibilityLabel("Nickname")
                    .placeholder("nickname")
            }

            SwitchRow("Editing", $editing)
                .horizontalAlignment(.start)

            // A ForEach whose row changes its KIND with the choice. The
            // row's identity is its ITEM, so moving the choice touches two
            // rows - each replaced for its new kind - and leaves the other
            // three alone.
            ForEach(0..<5) { turn in
                if turn == chosen {
                    Text("turn \(turn) - chosen")
                        .fontAttributes(.bold)
                        .textColor(Palette.accent)
                } else {
                    Button("turn \(turn)")
                        .horizontalAlignment(.start)
                        .onClicked { chosen = turn }
                }
            }

        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("An `if` above a view does not replace it: type in the field, flip the "
                + "switch, and the TextField keeps its control - and with it the text and "
                + "the caret.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Both branches of the `if/else` build a TextField, and they are still two "
                + "different elements: swapping replaces the control rather than editing "
                + "it, which is what the two branches say.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Five rows out of one `ForEach`, each choosing what to build. Moving "
                + "the choice sends two changes, not five: a row is identified by its "
                + "item, whatever the rows around it decide.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
