import StateUI

/// An application of several scenes: the galleries, the scratchpads, and About - one window for the whole
/// application, in a scene of its own.
struct ScenesSample: SampleContent, ExampleContent {
    // listing: ScenesSample
    /// The application as it runs - which opens a window in the scene declaring it.
    @Environment(\.application) private var application

    /// What the last button answered.
    @State private var said = "Nothing asked yet."
    // listing: end

    static let id = "scenes"
    static let title = "Scenes"
    static let summary = "Scratchpads are a scene of their own; About is a scene of one window."

    static var code: String { Listings.joined("GalleryApp", "ScratchpadScene", "AboutScene", "ScratchpadPage", "ScenesSample") }

    /// Devices whose host can present independent windows.
    static let formFactors: Set<FormFactor> = [.tablet, .desktop]

    var notes: (any View)? { nil }

    // listing: ScenesSample
    var body: some View {
        VStack {
            Button("New scratchpad")
                .horizontalAlignment(.center)
                .accessibilityIdentifier("scene.scratchpad")
                .onClicked(gate: .ignoreWhileRunning) { await open(.scratchpad, "New scratchpad") }

            Button("About")
                .horizontalAlignment(.center)
                .accessibilityIdentifier("scene.about")
                .onClicked(gate: .ignoreWhileRunning) { await open(.about, "About") }

            VStack {
                DebugInfoLabel()

                Text(said)
                    .fontSize(13)
                    .fontFamily("Menlo")
                    .textColor(Palette.accent)
                    .horizontalTextAlignment(.center)

                Text("Scenes open: \(application.scenes.count)")
                    .fontSize(13)
                    .horizontalTextAlignment(.center)
            }
            .spacing(4)
        }
        .spacing(12)
    }

    /// Opens a window of the kind `type` names, in the scene declaring it, and says what came of it.
    private func open(_ type: WindowType, _ caption: String) async {
        do {
            try await application.openWindow(type)
            said = "\(caption): opened."
        } catch WindowError.alreadyOpen {
            said = "\(caption): WindowError.alreadyOpen - it is open already."
        } catch {
            said = "\(caption): \(error)"
        }
    }
    // listing: end
}
