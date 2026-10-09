import StateUI

// listing: PropertyReadsSample
/// Two properties of one model, read in two different closures.
///
/// The point of the sample is which closure is built again: each property is
/// a `@State` of its own, so a write to `visits` reaches the closures that
/// read `visits` and nobody else.
@MainActor
private final class Profile {
    @State var name = ""
    @State var visits = 0
}
// listing: end

/// One model, two properties, two readers - and a write reaches one of them.
struct PropertyReadsSample: SampleContent, ExampleContent {
    // listing: PropertyReadsSample
    @State private var profile = Profile()
    // listing: end

    static let id = "propertyReads"
    static let title = "One write, one property"
    static let summary = "Two properties of one model are two states: a write reaches only that property's readers."

    // listing: PropertyReadsSample
    var body: some View {
        // THE OUTER CLOSURE READS NEITHER PROPERTY, so no write builds it
        // again and nothing below is carried along. Each block answers for
        // itself.
        VStack {
            VStack {
                Button("Another visit")
                    .accessibilityIdentifier("propertyReads.visit")
                    .horizontalAlignment(.center)
                    .onClicked { profile.visits += 1 }
            }

            VStack {
                DebugInfoLabel()

                Text("visits: \(profile.visits)")
                    .fontSize(17)
            }
            .spacing(4)
            .padding(14)
            .background(Palette.well)

            VStack {
                TextField(profile.$name)
                    .accessibilityIdentifier("propertyReads.name")
                    .accessibilityLabel("Name")
                    .placeholder("Type a name")
            }

            VStack {
                DebugInfoLabel()

                Text("name: \(profile.name.isEmpty ? "-" : profile.name)")
                    .fontSize(17)
                    .lineBreak(.tailTruncation)
            }
            .spacing(4)
            .padding(14)
            .background(Palette.well)
        }
        .spacing(14)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Press Another visit and the FIRST count moves while the second stands "
                + "still; type a name and the second moves while the first stands. One "
                + "model, two properties, and a write is about the property it was made "
                + "to - the same thing two separate pieces of state would do.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Each block says what it was built FOR - `2 builds, for visits` - and a "
                + "block carried along by a rebuilt parent says `with its parent` instead. "
                + "That is the line to watch: while the counts move one at a time and each "
                + "names its own property, the write reached one block and not the other.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The control and the reader are separate blocks so that each count is "
                + "about one thing. `profile.$name` is the name's own state, handed to the "
                + "field whole - the field reads nothing, so typing builds only the block "
                + "that shows the name.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("One write that is not yours: press Another visit with the caret still "
                + "in the field and the name count moves once more, because the field, "
                + "losing the focus, hands back its text as the platform finished it - the "
                + "first letter capitalized - and a changed text is a write to `name`. "
                + "Press the button again and only the visits count moves.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
