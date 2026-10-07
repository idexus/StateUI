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

    /// The device - a phone stands the two looks one under the other.
    @Environment(\.device) private var device
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
        // Read here, so a theme held anywhere builds the picker again at its
        // new place.
        let application = self.application
        let themes = Self.themes
        let theme = themes.firstIndex { $0.scheme == application.colorScheme } ?? 0

        return VStack {
            // A look for each theme: the gallery wears the one of the theme in
            // force, and changes with it. Side by side where there is room,
            // one under the other on a phone.
            if device.info.formFactor == .phone {
                LookColumn(title: "Light", style: style, keys: .light)
                LookColumn(title: "Dark", style: style, keys: .dark)
            } else {
                Grid {
                    LookColumn(title: "Light", style: style, keys: .light)
                        .gridColumn(0)
                    LookColumn(title: "Dark", style: style, keys: .dark)
                        .gridColumn(1)
                }
                .columns(.fill, .fill)
                .columnSpacing(16)
            }

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
            Text("Each theme has a look of its own: the gallery wears the one of the "
                + "theme in force, and turns to the other when the system's theme turns, "
                + "or the one the application holds. \"The platform's own\" leaves a choice "
                + "unwritten: each platform draws its own, in the user's accent, material "
                + "and theme. A colour paints the bars alone; what the window shows behind "
                + "the pages is its background.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Clear lets the desktop through the window sharp, a blur blurred - "
                + "where the platform can show it. The theme is the whole application's.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("\"The system's accent\" is the one the user chose, as `app.info.accentColor` "
                + "reports it - a change in the system's settings repaints the gallery.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

// listing: AppearanceSample
/// One theme's look: its bars and its window, each in a colour of its own,
/// and the window's blur - written where `keys` say.
private struct LookColumn: View {
    let title: String
    let style: SessionStyle
    let keys: LookKeys

    var body: some View {
        // Read here, so a choice made anywhere builds each picker again at its
        // new place.
        let style = self.style
        let keys = self.keys
        let look = ThemeLook(
            bars: style[keyPath: keys.bars], barColour: style[keyPath: keys.barColour],
            windows: style[keyPath: keys.windows], windowColour: style[keyPath: keys.windowColour],
            blur: style[keyPath: keys.blur])
        let bars = BarLook.allCases
        let windows = WindowLook.allCases
        let accents = AccentChoice.allCases
        let blurs: [Blur] = [.ultraThin, .thin, .regular, .thick, .ultraThick]
        let name = title.lowercased()

        return VStack {
            SectionTitle(title)

            Text("The bars")
                .fontSize(12)
                .textColor(Palette.subtle)
            Picker(bars.map(\.name))
                .accessibilityIdentifier("appearance.\(name).bars")
                .accessibilityLabel("Bars, \(name)")
                .selectedIndex(Binding(
                    get: { bars.firstIndex(of: look.bars) ?? 0 }, set: { style[keyPath: keys.bars] = bars[$0] }))
            Picker(accents.map(\.name))
                .accessibilityIdentifier("appearance.\(name).barColour")
                .accessibilityLabel("Bars' colour, \(name)")
                .isEnabled(look.bars == .tinted || look.bars == .colour)
                .selectedIndex(Binding(
                    get: { accents.firstIndex(of: look.barColour) ?? 0 },
                    set: { style[keyPath: keys.barColour] = accents[$0] }))

            Text("The window")
                .fontSize(12)
                .textColor(Palette.subtle)
            Picker(windows.map(\.name))
                .accessibilityIdentifier("appearance.\(name).window")
                .accessibilityLabel("Window, \(name)")
                .selectedIndex(Binding(
                    get: { windows.firstIndex(of: look.windows) ?? 0 },
                    set: { style[keyPath: keys.windows] = windows[$0] }))
            Picker(accents.map(\.name))
                .accessibilityIdentifier("appearance.\(name).windowColour")
                .accessibilityLabel("Window's colour, \(name)")
                .isEnabled(look.windows.showsColour)
                .selectedIndex(Binding(
                    get: { accents.firstIndex(of: look.windowColour) ?? 0 },
                    set: { style[keyPath: keys.windowColour] = accents[$0] }))
            Picker(["Ultra thin", "Thin", "Regular", "Thick", "Ultra thick"])
                .accessibilityIdentifier("appearance.\(name).blur")
                .accessibilityLabel("Window's blur, \(name)")
                .isEnabled(look.windows.showsBlur)
                .selectedIndex(Binding(
                    get: { blurs.firstIndex(of: look.blur) ?? 0 },
                    set: { style[keyPath: keys.blur] = blurs[$0] }))
        }
        .spacing(10)
    }
}
// listing: end
