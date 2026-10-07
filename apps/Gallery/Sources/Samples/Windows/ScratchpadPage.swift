import StateUI

// listing: ScratchpadPage
/// A scratchpad window's page: the scratchpads' one text, kept with their scene, and a way to close the window - or
/// every scratchpad window at once.
struct ScratchpadPage: View {
    /// The text, the scene's: every scratchpad window shows and writes it.
    @State(sceneKey: .scratch) private var text = ""

    /// The scratchpads - the scene the page is in, closed whole from here.
    @Environment(\.scene) private var scene

    /// The application as it runs - how many scenes stand.
    @Environment(\.application) private var application

    /// The window this is the page of - what it is called, how big, and closed from here.
    @Environment(\.window) private var window

    var body: some View {
        VStack {
            Text("Write anything: every scratchpad window shows this one text, and keeps it.")
                .fontSize(13)
                .textColor(Palette.subtle)

            TextEditor($text)
                .height(180)
                .accessibilityIdentifier("scratchpad.text")

            Text("Scratchpad windows: \(scene.windows.count) · scenes open: \(application.scenes.count)")
                .fontSize(13)
                .textColor(Palette.subtle)

            HStack {
                Button("Close this window")
                    .accessibilityIdentifier("scratchpad.close")
                    .onClicked { try await window.close() }

                Button("Close every scratchpad")
                    .accessibilityIdentifier("scratchpad.closeScene")
                    .onClicked { try await scene.close() }
            }
            .spacing(10)
            .horizontalAlignment(.end)
        }
        .spacing(10)
        .padding(16)
        .onCreated {
            window.title = "Scratchpad"
            window.width = 420
            window.height = 340
            window.minimumWidth = 320
            window.minimumHeight = 280
        }
    }
}
// listing: end
