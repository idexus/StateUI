import StateUI

// listing: EnvironmentSample
/// Who is signed in - the object a whole branch shares. Its properties are
/// `@State`, so a write to one rebuilds exactly the views that READ it.
private final class Session {
    @State var name = "guest"
    @State var visits = 0
}
// listing: end

// listing: EnvironmentSample
/// Reads the session - resolved by TYPE from the nearest `.environment` above,
/// no initializer argument anywhere on the way down.
private struct VisitBadge: View {
    @Environment var session: Session

    var body: some View {
        VStack {
            // The session is read in THIS closure, so a write to it builds
            // this closure and nothing above it.
            DebugInfoLabel()

            Text("\(session.name) - \(session.visits) visit(s)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(2)
    }
}
// listing: end

// listing: EnvironmentSample
/// Writes through the environment: `session.$name` is the provided object's
/// own state for the name, handed to the TextField whole - typing lands on it and
/// rebuilds the badge, which reads `name`.
private struct NameEditor: View {
    @Environment var session: Session

    var body: some View {
        TextField(session.$name)
            .accessibilityIdentifier("environment.name")
            .accessibilityLabel("Signed-in name")
            .placeholder("Signed-in name")
    }
}
// listing: end

/// An object provided above, resolved below - by type. The provider passes a
/// reference and reads no property, so it is never rebuilt by changes IN the
/// object; the readers are, each exactly when what it read moved.
struct EnvironmentSample: SampleContent, ExampleContent {
    // listing: EnvironmentSample
    @State private var session = Session()
    @State private var preview = Session()
    // listing: end

    static let id = "environment"
    static let title = "Environment"
    static let summary = "An object provided above, resolved below by type - @Environment reads the nearest one."

    // listing: EnvironmentSample
    var body: some View {
        VStack {
            // The provider hands a reference on and reads no property of it,
            // so a write in the object is none of this closure's business.
            DebugInfoLabel()

            VStack {
                VisitBadge()

                Button("Visit again")
                    .horizontalAlignment(.center)
                    .onClicked { session.visits += 1 }

                NameEditor()
            }
            .environment(session)
            .spacing(12)

            VisitBadge()
                .environment(preview)
        }
        .spacing(14)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The badge and the editor say `@Environment var session: Session` and "
                + "nothing is passed to them - the type is the key, and they resolve the "
                + "nearest Session provided above.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Press the button and watch the two readings: the badge is built "
                + "again, the closure around it is not - it passes a reference and reads "
                + "no property, so a write in the object is none of its business. Typing "
                + "in the TextField lands on `session.$name`, the provided object's own state "
                + "for the name.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The last badge sits under its OWN `.environment` - a different "
                + "Session, which its branch resolves, so the button moves nothing there.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
