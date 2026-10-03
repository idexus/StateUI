import StateUI

/// About the gallery: the page of one window for the whole application - a scene of one session, written in the
/// application's body. See `SceneKindsSample`.
struct AboutPage: View {
    /// The application as it runs - how many scenes stand.
    @Environment private var application: ApplicationSession

    /// The scene the window is - closed from here.
    @Environment private var scene: SceneSession

    /// The window this is the page of - what it is called, and how big.
    @Environment private var window: WindowSession

    /// The page itself - its padding.
    @Environment private var page: PageSession

    var body: some View {
        VStack {
            Text("StateUI Gallery")
                .fontSize(22)
                .horizontalTextAlignment(.center)

            Text("One window for the whole application: opening it again finds it open.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Text("\(application.scenes.count) scenes open")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Button("Close")
                .fontSize(13)
                .padding(horizontal: 14, vertical: 6)
                .horizontalAlignment(.center)
                .accessibilityIdentifier("about.close")
                .onClicked { try await scene.close() }
        }
        .spacing(12)
        .onCreated {
            page.padding = Insets(20)

            window.title = "About"
            window.width = 360
            window.height = 240
        }
    }
}
