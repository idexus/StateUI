import StateUI

/// The look the gallery wears, all of it in one place: its bars, what its
/// window and its sidebar are made of, each in a colour of its own, and its
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
    static let summary = "What the bars, the window and the sidebar are made of, and the theme: "
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
            // The theme first: which of the two looks below the gallery wears.
            SectionTitle("The theme")
            Picker(themes.map(\.name))
                .accessibilityIdentifier("appearance.theme")
                .accessibilityLabel("Theme")
                .selectedIndex(Binding(get: { theme }, set: { application.colorScheme = themes[$0].scheme }))

            // A look for each theme: the gallery wears the one of the theme in
            // force, and changes with it. Side by side where there is room,
            // one under the other on a phone.
            if device.info.formFactor == .phone {
                LookColumn(title: "Light", style: style, look: \.lightLook, choice: \.lightChoice)
                LookColumn(title: "Dark", style: style, look: \.darkLook, choice: \.darkChoice)
            } else {
                Grid {
                    LookColumn(title: "Light", style: style, look: \.lightLook, choice: \.lightChoice)
                        .gridColumn(0)
                    LookColumn(title: "Dark", style: style, look: \.darkLook, choice: \.darkChoice)
                        .gridColumn(1)
                }
                .columns(.fill, .fill)
                .columnSpacing(16)
            }
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Each theme has a look of its own: the gallery wears the one of the "
                + "theme in force, and turns to the other when the system's theme turns, "
                + "or the one the application holds. \"The gallery's own\" keeps no look: it is "
                + "the one this version of the gallery draws on this platform, at every start. "
                + "\"The platform's own\" leaves a choice "
                + "unwritten: each platform draws its own, in the user's accent, material "
                + "and theme. A colour paints the bars alone; what the window shows behind "
                + "the pages is its background. The sidebar stands on one material beside "
                + "the page and on another as it slides over it - a phone's drawer.")
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
/// One theme's look: its bars, and what its window, its sidebar and its
/// sidebar over the page are made of - written where `look` says, which makes
/// it the user's own; the gallery's own again where `choice` says.
private struct LookColumn: View {
    let title: String
    let style: SessionStyle
    let look: ReferenceWritableKeyPath<SessionStyle, ThemeLook>
    let choice: ReferenceWritableKeyPath<SessionStyle, LookChoice>

    var body: some View {
        // Read here, so a choice made anywhere builds each picker again at its
        // new place.
        let style = self.style
        let key = self.look
        let look = style[keyPath: key]
        let bars = BarLook.allCases
        let accents = AccentChoice.allCases
        let name = title.lowercased()
        // Each surface's choices write that part of the theme's look.
        let surface = { (part: WritableKeyPath<ThemeLook, SurfaceLook>) in
            Binding(get: { style[keyPath: key][keyPath: part] }, set: { style[keyPath: key][keyPath: part] = $0 })
        }

        let choice = self.choice
        let composed = style[keyPath: choice] != .own

        return VStack {
            SectionTitle(title)

            // Back to the look this gallery draws on this platform, whatever
            // it was when the user composed another.
            Button("The gallery's own")
                .accessibilityIdentifier("appearance.\(name).own")
                .isEnabled(composed)
                .onClicked { style[keyPath: choice] = .own }

            Text("The bars")
                .fontSize(12)
                .textColor(Palette.subtle)
            Picker(bars.map(\.name))
                .accessibilityIdentifier("appearance.\(name).bars")
                .accessibilityLabel("Bars, \(name)")
                .selectedIndex(Binding(
                    get: { bars.firstIndex(of: look.bars) ?? 0 }, set: { style[keyPath: key].bars = bars[$0] }))
            Picker(accents.map(\.name))
                .accessibilityIdentifier("appearance.\(name).barColour")
                .accessibilityLabel("Bars' colour, \(name)")
                .isEnabled(look.bars == .tinted || look.bars == .colour)
                .selectedIndex(Binding(
                    get: { accents.firstIndex(of: look.barColour) ?? 0 },
                    set: { style[keyPath: key].barColour = accents[$0] }))

            SurfacePickers(title: "The window", label: "Window", theme: name, surface: surface(\.window))
            SurfacePickers(title: "The sidebar", label: "Sidebar", theme: name, surface: surface(\.sidebar))
            SurfacePickers(title: "The sidebar over the page", label: "Flyout", theme: name, surface: surface(\.flyout))
        }
        .spacing(10)
    }
}

/// One surface's choices: what it is made of, in which colour, and how thick
/// a blur.
private struct SurfacePickers: View {
    let title: String
    let label: String
    let theme: String
    let surface: Binding<SurfaceLook>

    var body: some View {
        let surface = self.surface
        let look = surface.wrappedValue
        let materials = SurfaceMaterial.allCases
        let accents = AccentChoice.allCases
        let blurs = SurfaceLook.blurs
        let id = "appearance.\(theme).\(label.lowercased())"

        return VStack {
            Text(title)
                .fontSize(12)
                .textColor(Palette.subtle)
            Picker(materials.map(\.name))
                .accessibilityIdentifier(id)
                .accessibilityLabel("\(label), \(theme)")
                .selectedIndex(Binding(
                    get: { materials.firstIndex(of: look.material) ?? 0 },
                    set: { surface.wrappedValue.material = materials[$0] }))
            Picker(accents.map(\.name))
                .accessibilityIdentifier("\(id)Colour")
                .accessibilityLabel("\(label)'s colour, \(theme)")
                .isEnabled(look.material.showsColour)
                .selectedIndex(Binding(
                    get: { accents.firstIndex(of: look.colour) ?? 0 },
                    set: { surface.wrappedValue.colour = accents[$0] }))
            Picker(["Ultra thin", "Thin", "Regular", "Thick", "Ultra thick"])
                .accessibilityIdentifier("\(id)Blur")
                .accessibilityLabel("\(label)'s blur, \(theme)")
                .isEnabled(look.material.showsBlur)
                .selectedIndex(Binding(
                    get: { blurs.firstIndex(of: look.blur) ?? 0 },
                    set: { surface.wrappedValue.blur = blurs[$0] }))
        }
        .spacing(10)
    }
}
// listing: end
