import StateUI

/// Two properties of one model, read in two different closures.
///
/// The point of the sample is which closure is built again: `@StateClass`
/// gives every property a key of its own, so a write to `visits` reaches the
/// closures that read `visits` and nobody else.
@StateClass
private final class Profile {
    var name = ""
    var visits = 0
}

/// One model, two properties, two readers - and a write reaches one of them.
struct PropertyReadsSample: SampleContent {
    @State private var profile = Profile()

    static let id = "propertyReads"
    static let title = "One write, one property"
    static let summary = "Two properties of one model are two pieces of state: a write reaches the closures that read THAT property."

    static let code = """
        @StateClass
        final class Profile {
            var name = ""
            var visits = 0
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

            // Writes `name` - and READS it too: a binding to one property of a
            // model has no storage of its own, so the field takes the described
            // road, which reads the property as the line is written.
            VStack {
                Entry($profile.name)
                    .placeholder("Type a name")
            }

            // Reads `name`. Only a write to `name` builds this again.
            VStack {
                DebugInfoLabel()

                Label("name: \\(profile.name)")
            }
        }
        """

    var content: Element {
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
                Entry($profile.name)
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

            Label("The control and the reader are separate blocks on purpose. A field over "
                + "`$profile.name` READS that property where the line is written - a "
                + "binding to one property of a model has no storage of its own, so the "
                + "control takes the described road - and one written beside a reader of "
                + "`visits` would put both in one closure and rebuild them together.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("One thing that is not a write: typing and THEN pressing Another visit "
                + "moves the name count once as well, because the field is losing the "
                + "focus and a field reports that. Press the button twice and the second "
                + "press leaves it alone.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
