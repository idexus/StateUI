import StateUI

/// The theme as a value a view can branch on.
struct AppThemeSample: SampleContent, ExampleContent {
    /// The application's information, where the theme is read.
    @Environment(\.application) var app

    static let id = "appTheme"
    static let title = "Theme"
    static let summary = "The theme as a value a view can branch on - "
        + "updated live when the system switches."

    static let code = """
        struct ThemeBadge: View {
            @Environment(\\.application) var app

            var body: some View {
                VStack {
                    // The theme is read here, so a change to it builds this
                    // closure.
                    DebugInfoLabel()

                    Text("\\(app.info.colorScheme)")

                    // LOGIC on the theme - a different WORD, not a colour.
                    // A colour that differs by theme is Color(light:dark:),
                    // which follows by itself.
                    Text(app.info.colorScheme == .dark
                        ? "lights off - a view can choose calmer artwork"
                        : "lights on - a view can choose vivid artwork")
                }
            }
        }
        """

    var body: some View {
        VStack {
            DebugInfoLabel()

            Text("\(app.info.colorScheme)")
                .fontSize(34)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Text(app.info.colorScheme == .dark
                ? "lights off - a view can choose calmer artwork"
                : "lights on - a view can choose vivid artwork")
                .fontSize(15)
                .horizontalTextAlignment(.center)
        }
        .spacing(10)
    }

    var notes: (any View)? {
        VStack {
            Text("Switch the SYSTEM's appearance and the word above follows "
                + "in the same breath.")
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
