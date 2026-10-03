import StateUI

/// An application of several kinds of scene, each named by its main window: the galleries, a scratchpad of its own
/// kind, and one About window for the whole application.
struct SceneKindsSample: SampleContent, ExampleContent {
    /// The application as it runs - which opens a scene of each kind.
    @Environment private var application: ApplicationSession

    /// What the last button answered.
    @State private var said = "Nothing asked yet."

    static let id = "scene-kinds"
    static let title = "Kinds of scene"
    static let summary = "A scratchpad is a scene of its own kind; About is one window for the application."

    /// Devices whose host can present independent windows.
    static let formFactors: Set<FormFactor> = [.tablet, .desktop]

    static let code = """
        extension WindowType {
            static let scratchpad = WindowType("gallery.scratchpad")
            static let about = WindowType("gallery.about")
        }

        struct GalleryApp: Application {
            var body: some Scene {
                GalleryScene()                          // the first kind: launch and File ▸ New
                ScratchpadScene()                       // a kind of its own
                Window(.about) { AboutPage() }          // one for the whole application
            }
        }

        struct ScratchpadScene: Scene {
            var body: some Scene {
                WindowGroup(.scratchpad) { ScratchpadPage() }   // names the kind
            }
        }

        struct ScratchpadPage: View {
            @State(sceneKey: .scratch) private var text = ""   // each scratchpad's own
            @Environment private var scene: SceneSession

            var body: some View {
                VStack {
                    TextEditor($text)
                    Button("Close this scratchpad").onClicked { try await scene.close() }
                }
            }
        }

        @Environment private var application: ApplicationSession

        Button("New scratchpad").onClicked { try await application.openWindow(.scratchpad) }
        Button("About").onClicked { try await application.openWindow(.about) }   // alreadyOpen once open

        VStack {
            DebugInfoLabel()
            Text(said)
            Text("\\(application.scenes.count) scenes open")
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

                Text("\(application.scenes.count) scenes open")
                    .fontSize(13)
                    .horizontalTextAlignment(.center)
            }
            .spacing(4)
        }
        .spacing(12)
    }

    /// Opens a scene of the kind `type` names, and says what came of it.
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
