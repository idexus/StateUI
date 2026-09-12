import StateUI

/// Two properties of one model, read in two different closures.
///
/// The point of the sample is which closure is built again: each property is
/// a `@State` of its own, so a write to `visits` reaches the closures that
/// read `visits` and nobody else.
private final class Profile {
    @State var name = ""
    @State var visits = 0
}

/// One model, two properties, two readers - and a write reaches one of them.
struct PropertyReadsSample: SampleContent {
    @State private var profile = Profile()

    static let id = "propertyReads"
    static let title = "One write, one property"
    static let summary = "Two properties of one model are two pieces of state: a write reaches the closures that read THAT property."

    static let code = """
        final class Profile {
            @State var name = ""
            @State var visits = 0
        }

        @State private var profile = Profile()

        // THE OUTER CLOSURE READS NEITHER PROPERTY, so no write builds it
        // again and nothing below is carried along. Each block answers for
        // itself.
        VStack {
            // Writes `visits`. A handler reads when it FIRES, not when it is
            // written, so this closure reads nothing at all.
            VStack {
                Button("Another visit")
                    .onClicked { profile.visits += 1 }
            }

            // Reads `visits`. Only a write to `visits` builds this again.
            VStack {
                DebugInfoLabel()

                Label("visits: \\(profile.visits)")
            }

            // Writes `name` and reads nothing: `profile.$name` is the name's
            // own state, handed to the host whole, so the field is no reader.
            VStack {
                Entry(profile.$name)
                    .placeholder("Type a name")
            }

            // Reads `name`. Only a write to `name` builds this again.
            VStack {
                DebugInfoLabel()

                Label("name: \\(profile.name)")
            }
        }
        """

    var content: any View {
        // THE OUTER CLOSURE READS NEITHER PROPERTY, so no write builds it
        // again and nothing below is carried along. Each block answers for
        // itself.
        VStack {
            VStack {
                Button("Another visit")
                    .automationId("propertyReads.visit")
                    .fontSize(13)
                    .backgroundColor(Palette.accent)
                    .textColor(.white)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .horizontalOptions(.center)
                    .onClicked { profile.visits += 1 }
            }

            VStack {
                DebugInfoLabel()

                Label("visits: \(profile.visits)")
                    .fontSize(17)
            }
            .spacing(4)
            .padding(14)
            .backgroundColor(Palette.surface)

            VStack {
                Entry(profile.$name)
                    .automationId("propertyReads.name")
                    .semanticDescription("Name")
                    .placeholder("Type a name")
            }

            VStack {
                DebugInfoLabel()

                Label("name: \(profile.name.isEmpty ? "-" : profile.name)")
                    .fontSize(17)
                    .lineBreakMode(.tailTruncation)
            }
            .spacing(4)
            .padding(14)
            .backgroundColor(Palette.surface)
        }
        .spacing(14)
    }

    var notes: Element? {
        VStack {
            Label("Press Another visit and the FIRST count moves while the second stands "
                + "still; type a name and the second moves while the first stands. One "
                + "model, two properties, and a write is about the property it was made "
                + "to - the same thing two separate pieces of state would do.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Each block says what it was built FOR - `2 builds, for visits` - and a "
                + "block carried along by a rebuilt parent says `with its parent` instead. "
                + "That is the line to watch: while the counts move one at a time and each "
                + "names its own property, the write reached one block and not the other.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The control and the reader are separate blocks so that each count is "
                + "about one thing. `profile.$name` is the name's own state, handed to the "
                + "field whole - the field reads nothing, so typing builds only the block "
                + "that shows the name.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("One write that is not yours: press Another visit with the caret still "
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
