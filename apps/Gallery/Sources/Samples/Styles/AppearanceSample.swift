import StateUI

/// The look the gallery wears, all of it in one place: its bars and what its
/// windows show behind their pages, each in a colour of its own, and its
/// theme.
struct AppearanceSample: SampleContent, ExampleContent {
    // listing: AppearanceSample
    /// The gallery's look, which every gallery window wears.
    let style: SessionStyle

    /// The application, whose theme is held here.
    @Environment(\.application) private var application
    // listing: end

    static let id = "appearance"
    static let title = "Appearance"
    static let summary = "The bars, the window behind the pages, their colours and the theme: "
        + "the platform's own, or yours."

    static var code: String { Listings.joined("AppearanceSample", "Gallery.Looks") }

    // listing: AppearanceSample
    /// The themes the application may hold, in the order they are offered.
    private static let themes: [(name: String, scheme: ColorScheme)] = [
        ("The system's", .system), ("Light", .light), ("Dark", .dark),
    ]

    var body: some View {
        // Read here, so a choice made anywhere - this page, the Colours
        // window - builds each picker again at its new place.
        let style = self.style
        let application = self.application
        let bars = BarLook.allCases
        let windows = WindowLook.allCases
        let accents = AccentChoice.allCases
        let themes = Self.themes
        let bar = bars.firstIndex(of: style.bars) ?? 0
        let window = windows.firstIndex(of: style.windows) ?? 0
        let barColour = accents.firstIndex(of: style.barColour) ?? 0
        let windowColour = accents.firstIndex(of: style.windowColour) ?? 0
        let theme = themes.firstIndex { $0.scheme == application.colorScheme } ?? 0

        return VStack {
            SectionTitle("The bars")
            Picker(bars.map(\.name))
                .accessibilityIdentifier("appearance.bars")
                .accessibilityLabel("Bars")
                .selectedIndex(Binding(get: { bar }, set: { style.bars = bars[$0] }))
            Picker(accents.map(\.name))
                .accessibilityIdentifier("appearance.barColour")
                .accessibilityLabel("Bars' colour")
                .isEnabled(style.bars == .tinted || style.bars == .colour)
                .selectedIndex(Binding(get: { barColour }, set: { style.barColour = accents[$0] }))

            SectionTitle("The window")
            Picker(windows.map(\.name))
                .accessibilityIdentifier("appearance.window")
                .accessibilityLabel("Window")
                .selectedIndex(Binding(get: { window }, set: { style.windows = windows[$0] }))
            Picker(accents.map(\.name))
                .accessibilityIdentifier("appearance.windowColour")
                .accessibilityLabel("Window's colour")
                .isEnabled(style.windows == .tintedMaterial || style.windows == .colour)
                .selectedIndex(Binding(get: { windowColour }, set: { style.windowColour = accents[$0] }))

            SectionTitle("The theme")
            Picker(themes.map(\.name))
                .accessibilityIdentifier("appearance.theme")
                .accessibilityLabel("Theme")
                .selectedIndex(Binding(get: { theme }, set: { application.colorScheme = themes[$0].scheme }))
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("\"The platform's own\" leaves a choice unwritten: each platform draws its "
                + "own, in the user's accent, material and theme. A colour paints the bars "
                + "alone; what the window shows behind the pages is its background.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Clear lets the desktop through the window sharp, the material blurred - "
                + "where the platform can show it. The theme is the whole application's.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
