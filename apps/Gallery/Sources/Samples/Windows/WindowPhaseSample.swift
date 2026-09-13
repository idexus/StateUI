import StateUI

/// Where the application, this gallery and this window stand - the phases of
/// the three sessions a page is in, each a value any view can read, where the
/// Lifecycle sample logs a window's moments as they happen.
struct WindowPhaseSample: SampleContent {
    /// The application as it runs.
    @Environment var application: ApplicationSession

    /// This gallery - the scene the page is in.
    @Environment var scene: SceneSession

    /// The window this page is in, its phase moved by the platform's own
    /// lifecycle events.
    @Environment var window: WindowSession

    static let id = "windowPhase"
    static let title = "Phases"
    static let summary = "Where the application, this gallery and this window stand - "
        + "three values any view can read."

    static let code = """
        @Environment private var application: ApplicationSession
        @Environment private var scene: SceneSession
        @Environment private var window: WindowSession

        VStack {
            // All three are read here, so a move of any of them builds this
            // closure again.
            DebugInfoLabel()

            Label("application · \\(application.phase)")   // active, inactive or background
            Label("this gallery · \\(scene.phase)")        // active, inactive or background
            Label("this window · \\(window.phase)")        // from created to destroying
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            PhaseRow(name: "application", value: "\(application.phase)")
            PhaseRow(name: "this gallery", value: "\(scene.phase)")
            PhaseRow(name: "this window", value: "\(window.phase)")

            Label(verdict)
                .fontSize(14)
                .textColor(Palette.accent)
                .horizontalTextAlignment(.center)
        }
        .spacing(10)
    }

    /// What the three say together.
    private var verdict: String {
        if application.phase == .background {
            return "The application is out of sight."
        }

        if application.phase != .active {
            return "Another application is in front."
        }

        if scene.phase != .active {
            return "Another gallery is in front of this one."
        }

        return "This gallery is the one in front."
    }

    var notes: Element? {
        VStack {
            Label("Every session is in the environment of everything under it, and its "
                + "phase is state like any other: this page reads all three, so it is "
                + "built again whenever one of them moves. Something that must happen AT "
                + "a moment watches one with .onChanged - the Lifecycle sample's log is "
                + "the window's phase watched that way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Open a second gallery and click between the two: this gallery's phase "
                + "moves between active and inactive. Hide the application and bring it "
                + "back: the application and the gallery go to the background, the window "
                + "to stopped, and all three come back.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("WHEN a window's phase moves is the platform's: an Android phone says "
                + "deactivated then stopped on every trip through the home screen, while "
                + "Mac Catalyst raises nothing on a mere switch to another application and "
                + "moves only around hiding and showing it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}

/// One phase: whose it is, and where it stands.
private struct PhaseRow: ContentView {
    let name: String
    let value: String

    var content: any View {
        HStack {
            Label(name)
                .fontSize(13)
                .textColor(Palette.subtle)
                .widthRequest(110)
                .verticalOptions(.center)

            Label(value)
                .fontSize(24)
                .fontAttributes(.bold)
                .verticalOptions(.center)
        }
        .spacing(12)
        .horizontalOptions(.center)
    }
}
