import StateUI

/// The application's session, in every view's environment: the motion every
/// value in the application takes when nothing nearer says another.
struct ApplicationSessionSample: SampleContent, ExampleContent {
    // listing: ApplicationSessionSample
    /// The application as it runs - one for the whole process.
    @Environment(\.application) var application

    @State private var wide = false
    // listing: end

    static let id = "applicationSession"
    static let title = "Application session"
    static let summary = "The application's session, read and written like any state - here the motion values take by default."

    // listing: ApplicationSessionSample
    static let laws: [Motion] = [.standard, .spring(response: 320, damping: 0.6), .none]

    /// What the picker calls a law.
    static func name(_ law: Motion) -> String {
        switch law {
        case .standard: "Standard"
        case .none: "None"
        default: "Spring"
        }
    }

    var body: some View {
        VStack {
            // `application.motion` and `wide` are read here, so a choice or a
            // press builds this closure.
            DebugInfoLabel()

            Text("Pick None, then open another sample: only what has a motion of its own still travels.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            // One write for the whole application: every value without a
            // motion of its own takes it.
            Picker(Self.laws, selection: Binding(get: { application.motion }, set: { application.motion = $0 }),
                   caption: Self.name)
                .horizontalAlignment(.center)

            // No `.motion` here: the panel takes the application's.
            Rectangle(wide ? Palette.accent : Palette.brand)
                .width(wide ? 300 : 120)
                .height(60)
                .cornerRadius(8)
                .horizontalAlignment(.center)

            Button("Change")
                .horizontalAlignment(.center)
                .onClicked { wide.toggle() }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The application's session holds what is the whole process's: its phase, its open "
                + "scenes, its styles, its motion and the keys it keeps. The scene's and the window's "
                + "sessions are under Scene.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A view nearer the value still answers first: `.motion(_:)` on a view, "
                + "`@State(motion:)` on a state, `$state.journey.snap(to:)` on one write.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
