import StateUI

/// The theme as a value a view can branch on.
struct AppThemeSample: SampleContent, ExampleContent {
    /// The application's information, where the theme is read.
    @Environment var app: AppInfo

    static let id = "appTheme"
    static let title = "AppTheme"
    static let summary = "The theme as a value a view can branch on - "
        + "updated live when the system switches."

    static let code = """
        struct ThemeBadge: ContentView {
            @Environment var app: AppInfo

            var content: any View {
                VStack {
                    // The theme is read here, so a change to it builds this
                    // closure.
                    DebugInfoLabel()

                    Label("\\(app.requestedTheme)")

                    // LOGIC on the theme - a different WORD, not a colour.
                    // A colour that differs by theme is Color(light:dark:),
                    // which follows by itself.
                    Label(app.requestedTheme == .dark
                        ? "lights off - a view can choose calmer artwork"
                        : "lights on - a view can choose vivid artwork")
                }
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label("\(app.requestedTheme)")
                .fontSize(34)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label(app.requestedTheme == .dark
                ? "lights off - a view can choose calmer artwork"
                : "lights on - a view can choose vivid artwork")
                .fontSize(15)
                .horizontalTextAlignment(.center)
        }
        .spacing(10)
    }

    var notes: Element? {
        VStack {
            Label("Switch the SYSTEM's appearance and the word above follows "
                + "in the same breath.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Use this for LOGIC - a different picture, a different word. A "
                + "colour should not need it: a `Color(light:dark:)` reads the theme "
                + "as the view wearing it is built, so a theme change builds exactly "
                + "the views wearing one again.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
