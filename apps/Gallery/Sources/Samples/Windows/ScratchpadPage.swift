import StateUI

/// One scratchpad's page: its text, kept with its scene, and a way to close it.
struct ScratchpadPage: View {
    /// The text, this scratchpad's own.
    @State(sceneKey: .scratch) private var text = ""

    /// This scratchpad - the scene the page is in.
    @Environment private var scene: SceneSession

    /// The application as it runs - how many scenes stand.
    @Environment private var application: ApplicationSession

    /// The window this is the page of - what it is called, and how big.
    @Environment private var window: WindowSession

    /// The page itself - its padding.
    @Environment private var page: PageSession

    var body: some View {
        VStack {
            Text("Write anything: this scratchpad keeps it, and another keeps its own.")
                .fontSize(13)
                .textColor(Palette.subtle)

            TextEditor($text)
                .height(180)
                .accessibilityIdentifier("scratchpad.text")

            Text("\(application.scenes.count) scenes open")
                .fontSize(13)
                .textColor(Palette.subtle)

            Button("Close this scratchpad")
                .fontSize(13)
                .padding(horizontal: 14, vertical: 6)
                .horizontalAlignment(.end)
                .accessibilityIdentifier("scratchpad.close")
                .onClicked { try await scene.close() }
        }
        .spacing(10)
        .onCreated {
            page.padding = Insets(16)

            window.title = "Scratchpad"
            window.width = 420
            window.height = 340
            window.minimumWidth = 320
            window.minimumHeight = 280
        }
    }
}
