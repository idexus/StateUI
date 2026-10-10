import StateUI

/// The theme as a value a view can branch on.
struct AppThemeSample: SampleContent, ExampleContent {
    // listing: AppThemeSample
    /// The application's information, where the theme is read.
    @Environment(\.application) var app
    // listing: end

    static let id = "appTheme"
    static let title = "Theme"
    static let summary = "The theme as a value a view can branch on - "
        + "updated live as the theme in force changes."

    // listing: AppThemeSample
    var body: some View {
        VStack {
            // The theme is read here, so a change to it builds this
            // closure.
            DebugInfoLabel()

            Text("\(app.info.colorScheme)")
                .fontSize(34)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            // LOGIC on the theme - a different WORD, not a colour.
            // A colour that differs by theme is Color(light:dark:),
            // which follows by itself.
            Text(app.info.colorScheme == .dark
                ? "lights off - a view can choose calmer artwork"
                : "lights on - a view can choose vivid artwork")
                .fontSize(15)
                .horizontalTextAlignment(.center)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Switch the SYSTEM's appearance and the word above follows "
                + "in the same breath, while the application holds no theme of its "
                + "own. On GNOME the gallery opens held in the dark; the Appearance "
                + "sample's \"The system's\" lets it follow.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Use this for LOGIC - a different picture, a different word. A "
                + "colour should not need it: a `Color(light:dark:)` reads the theme "
                + "as the view wearing it is built, so a theme change builds exactly "
                + "the views wearing one again.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
