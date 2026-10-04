import StateUI

/// The three lifecycle scopes available to every view in a window.
struct WindowPhaseSample: SampleContent, ExampleContent {
    /// The application as it runs.
    @Environment(\.application) var application

    /// The galleries - the scene the page is in.
    @Environment(\.scene) var scene

    /// The window this page is in.
    @Environment(\.window) var window

    static let id = "windowPhase"
    static let title = "Phases"
    static let summary = "Read application, scene, and window lifecycle as state."

    static let code = """
        @Environment(\\.application) private var application
        @Environment(\\.scene) private var scene
        @Environment(\\.window) private var window

        VStack {
            DebugInfoLabel()

            Text("application · \\(application.phase)")   // active, inactive or background
            Text("this gallery · \\(scene.phase)")        // active, inactive or background
            Text("this window · \\(window.phase)")        // from created to destroying
        }
        """

    var notes: (any View)? { nil }

    var body: some View {
        VStack {
            DebugInfoLabel()

            PhaseRow(name: "application", value: "\(application.phase)")
            PhaseRow(name: "this gallery", value: "\(scene.phase)")
            PhaseRow(name: "this window", value: "\(window.phase)")

            Text(verdict)
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

}

/// One phase: whose it is, and where it stands.
private struct PhaseRow: View {
    let name: String
    let value: String

    var body: some View {
        HStack {
            Text(name)
                .fontSize(13)
                .textColor(Palette.subtle)
                .width(110)
                .verticalAlignment(.center)

            Text(value)
                .fontSize(24)
                .fontAttributes(.bold)
                .verticalAlignment(.center)
        }
        .spacing(12)
        .horizontalAlignment(.center)
    }
}
