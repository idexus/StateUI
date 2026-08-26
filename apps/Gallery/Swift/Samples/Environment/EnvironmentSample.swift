import StateUI

/// Who is signed in - the object a whole branch shares. A `@StateClass`, so a
/// write to any property rebuilds exactly the views that READ it.
@StateClass
private final class Session {
    var name = "guest"
    var visits = 0
}

/// Counts how often a body ran. A plain class the render knows nothing about:
/// each build increments it and shows the number it got to, so a view that is
/// NOT rebuilt keeps showing the old count - which is the demonstration.
private final class Builds {
    var count = 0
}

/// Reads the session - resolved by TYPE from the nearest `.environment` above,
/// no initializer argument anywhere on the way down.
private struct VisitBadge: ContentView {
    let builds: Builds
    @Environment var session: Session

    var content: Element {
        builds.count += 1
        return VStack {
            Label("\(session.name) - \(session.visits) visit(s)")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Label("this view built \(builds.count)x")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(2)
    }
}

/// Writes through the environment: `$session.name` lends ONE property of the
/// provided object to an Entry, the model rule.
private struct NameEditor: ContentView {
    @Environment var session: Session

    var content: Element {
        Entry($session.name)
            .placeholder("Signed-in name")
    }
}

/// An object provided above, resolved below - by type. The provider passes a
/// reference and reads no property, so it is never rebuilt by changes IN the
/// object; the readers are, each exactly when what it read moved.
struct EnvironmentSample: SampleContent {
    @State private var session = Session()
    @State private var preview = Session()
    private let providerBuilds = Builds()
    private let badgeBuilds = Builds()
    private let previewBuilds = Builds()

    static let id = "environment"
    static let title = "Environment"
    static let summary = "An object provided above, resolved below by type - @Environment reads the nearest one."

    static let code = """
        @StateClass
        final class Session {
            var name = "guest"
            var visits = 0
        }

        // Counts how often a body ran - a plain class the render knows
        // nothing about, so a view that is NOT rebuilt keeps showing the
        // count it reached last time.
        final class Builds {
            var count = 0
        }

        struct VisitBadge: ContentView {
            let builds: Builds
            @Environment var session: Session

            var content: Element {
                builds.count += 1
                return VStack {
                    Label("\\(session.name) - \\(session.visits) visit(s)")
                    Label("this view built \\(builds.count)x")
                }
            }
        }

        struct NameEditor: ContentView {
            @Environment var session: Session

            var content: Element {
                Entry($session.name)
                    .placeholder("Signed-in name")
            }
        }

        struct RootView: ContentView {
            @State private var session = Session()
            @State private var preview = Session()
            private let providerBuilds = Builds()
            private let badgeBuilds = Builds()
            private let previewBuilds = Builds()

            var content: Element {
                providerBuilds.count += 1
                return VStack {
                    VStack {
                        VisitBadge(builds: badgeBuilds)

                        Button("Visit again")
                            .onClicked { session.visits += 1 }

                        NameEditor()
                    }
                    .environment(session)

                    Label("provider built \\(providerBuilds.count)x")

                    VisitBadge(builds: previewBuilds)
                        .environment(preview)
                }
            }
        }
        """

    var content: Element {
        providerBuilds.count += 1
        return VStack {
            VStack {
                VisitBadge(builds: badgeBuilds)

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

            Label("provider built \(providerBuilds.count)x")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Label("The badge and the editor say `@Environment var session: Session` and "
                + "nothing is passed to them - the type is the key, and they resolve the "
                + "nearest Session provided above. Press the button and watch the counts: "
                + "the badge rebuilds, the provider does not - it passes a reference and "
                + "reads no property, so a write in the object is none of its business. "
                + "Typing in the Entry writes back through `$session.name`, one lent "
                + "property of the provided object.")
                .fontSize(12)
                .textColor(Palette.subtle)

            VisitBadge(builds: previewBuilds)
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
