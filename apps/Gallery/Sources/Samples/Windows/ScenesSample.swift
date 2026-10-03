import StateUI

/// An application of several scenes: the galleries, the scratchpads, and About - one window for the whole
/// application, in a scene of its own.
struct ScenesSample: SampleContent, ExampleContent {
    /// The application as it runs - which opens a window in the scene declaring it.
    @Environment private var application: ApplicationSession

    /// What the last button answered.
    @State private var said = "Nothing asked yet."

    static let id = "scenes"
    static let title = "Scenes"
    static let summary = "Scratchpads are a scene of their own; About is a scene of one window."

    /// Devices whose host can present independent windows.
    static let formFactors: Set<FormFactor> = [.tablet, .desktop]

    static let code = """
        extension WindowType {
            static let scratchpad = WindowType("gallery.scratchpad")
            static let about = WindowType("gallery.about")
        }

        struct GalleryApp: Application {
            var body: some Scene {
                GalleryScene()                          // launch and File ▸ New: one more gallery window
                ScratchpadScene()
                AboutScene()                            // one window for the whole application
            }
        }

        struct ScratchpadScene: Scene {
            var body: some Scene {
                WindowGroup(.scratchpad) { ScratchpadPage() }   // as many as are opened
            }
        }

        struct AboutScene: Scene {
            var body: some Scene {
                Window(.about) { AboutPage() }          // a scene of its own, in no gallery
            }
        }

        struct ScratchpadPage: View {
            @State(sceneKey: .scratch) private var text = ""   // the scene's: every scratchpad window shows it
            @Environment private var window: WindowSession
            @Environment private var scene: SceneSession

            var body: some View {
                VStack {
                    TextEditor($text)
                    Button("Close this window").onClicked { try await window.close() }
                    Button("Close every scratchpad").onClicked { try await scene.close() }
                }
            }
        }

        @Environment private var application: ApplicationSession

        // A window opens in the scene declaring its kind, which opens with it where it does not stand.
        Button("New scratchpad").onClicked { try await application.openWindow(.scratchpad) }
        Button("About").onClicked { try await application.openWindow(.about) }   // alreadyOpen once open

        VStack {
            DebugInfoLabel()
            Text(said)
            Text("Scenes open: \\(application.scenes.count)")
        }
        """

    var notes: (any View)? { nil }

    var body: some View {
        VStack {
            Button("New scratchpad")
                .background(Palette.accent)
                .textColor(.white)
                .shape(.roundedRectangle(8))
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .accessibilityIdentifier("scene.scratchpad")
                .onClicked { await open(.scratchpad, "New scratchpad") }

            Button("About")
                .fontSize(13)
                .padding(horizontal: 14, vertical: 6)
                .horizontalAlignment(.center)
                .accessibilityIdentifier("scene.about")
                .onClicked { await open(.about, "About") }

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
}
