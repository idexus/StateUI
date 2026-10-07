import StateUI

/// About the gallery: the page of one window for the whole application, in a scene of its own. See `AboutScene`.
struct AboutPage: View {
    /// The application as it runs - how many scenes stand.
    @Environment(\.application) private var application

    /// The window this is the page of - what it is called, how big, and closed from here: its scene ends with it.
    @Environment(\.window) private var window

    var body: some View {
        VStack {
            Text("StateUI Gallery")
                .fontSize(22)
                .horizontalTextAlignment(.center)

            Text("One window for the whole application: opening it again finds it open.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Text("Scenes open: \(application.scenes.count)")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Button("Close")
                .horizontalAlignment(.center)
                .accessibilityIdentifier("about.close")
                .onClicked { try await window.close() }
        }
        .spacing(12)
        .padding(20)
        .onCreated {
            window.title = "About"
            window.width = 360
            window.height = 240
        }
    }
}
