import StateUI

/// Who is signed in - the object a whole branch shares. Its properties are
/// `@State`, so a write to one rebuilds exactly the views that READ it.
private final class Session {
    @State var name = "guest"
    @State var visits = 0
}

/// Reads the session - resolved by TYPE from the nearest `.environment` above,
/// no initializer argument anywhere on the way down.
private struct VisitBadge: ContentView {
    @Environment var session: Session

    var content: Element {
        VStack {
            // The session is read in THIS closure, so a write to it builds
            // this closure and nothing above it.
            DebugInfoLabel()

            Label("\(session.name) - \(session.visits) visit(s)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(2)
    }
}

/// Writes through the environment: `session.$name` is the provided object's
/// own state for the name, handed to the Entry whole - typing lands on it and
/// rebuilds the badge, which reads `name`.
private struct NameEditor: ContentView {
    @Environment var session: Session

    var content: Element {
        Entry(session.$name)
            .automationId("environment.name")
            .semanticDescription("Signed-in name")
            .placeholder("Signed-in name")
    }
}

/// An object provided above, resolved below - by type. The provider passes a
/// reference and reads no property, so it is never rebuilt by changes IN the
/// object; the readers are, each exactly when what it read moved.
struct EnvironmentSample: SampleContent {
    @State private var session = Session()
    @State private var preview = Session()

    static let id = "environment"
    static let title = "Environment"
    static let summary = "An object provided above, resolved below by type - @Environment reads the nearest one."

    static let code = """
        final class Session {
            @State var name = "guest"
            @State var visits = 0
        }

        struct VisitBadge: ContentView {
            @Environment var session: Session

            var content: Element {
                VStack {
                    // The session is read in THIS closure, so a write to it
                    // builds this closure and nothing above it.
                    DebugInfoLabel()

                    Label("\\(session.name) - \\(session.visits) visit(s)")
                }
            }
        }

        struct NameEditor: ContentView {
            @Environment var session: Session

            var content: Element {
                Entry(session.$name)
                    .placeholder("Signed-in name")
            }
        }

        struct RootView: ContentView {
            @State private var session = Session()
            @State private var preview = Session()

            var content: Element {
                VStack {
                    // The provider hands a reference on and reads no property
                    // of it, so a write in the object builds nothing here.
                    DebugInfoLabel()

                    VStack {
                        VisitBadge()

                        Button("Visit again")
                            .onClicked { session.visits += 1 }

                        NameEditor()
                    }
                    .environment(session)

                    VisitBadge()
                        .environment(preview)
                }
            }
        }
        """

    var content: Element {
        VStack {
            // The provider hands a reference on and reads no property of it,
            // so a write in the object is none of this closure's business.
            DebugInfoLabel()

            VStack {
                VisitBadge()

                Button("Visit again")
                    .backgroundColor(Palette.accent)
                    .textColor(.white)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .horizontalOptions(.center)
                    .onClicked { session.visits += 1 }

                NameEditor()
            }
            .environment(session)
            .spacing(12)

            Label("The badge and the editor say `@Environment var session: Session` and "
                + "nothing is passed to them - the type is the key, and they resolve the "
                + "nearest Session provided above. Press the button and watch the two "
                + "readings: the badge is built again, the closure around it is not - it "
                + "passes a reference and reads no property, so a write in the object is "
                + "none of its business. "
                + "Typing in the Entry lands on `session.$name`, the provided object's "
                + "own state for the name.")
                .fontSize(12)
                .textColor(Palette.subtle)

            VisitBadge()
                .environment(preview)
        }
        .spacing(14)
    }

    var notes: Element? {
        Label("This second badge sits under its OWN `.environment` - a different "
            + "Session, so the branch resolves that one: a nearer provider wins for "
            + "its branch, and the button above moves nothing here.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
