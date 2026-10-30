import StateUI

/// The look the gallery wears, all of it in one place: its bars, what its
/// window and its sidebar are made of, each in a color of its own, and its
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

    static var code: String { Listings.joined("AppearanceSample", "MainPage.look", "Gallery.Looks", "AppStyles.bars") }

    // listing: AppearanceSample
    /// The themes the application may hold, in the order they are offered.
    private static let themes: [(name: String, scheme: ColorScheme)] = [
        ("The system's", .system), ("Light", .light), ("Dark", .dark),
    ]

    /// How the bars' buttons may stand, in the order they are offered.
    private static let toolbarStyles: [(name: String, style: ToolbarStyle)] = [
        ("The Web's own", .system), ("Glass", .glass), ("Plain", .plain), ("Rounded", .rounded),
    ]

    /// The accents the application may hold, the platform's first.
    private static let accents: [(name: String, color: Color?)] =
        [("The platform's", nil)] + AccentChoice.own.map { ($0.name, $0.color(system: .accent, for: .bar)) }

    var body: some View {
        // Read here, so a theme held anywhere builds the picker again at its
        // new place.
        let application = self.application
        let themes = Self.themes
        let accents = Self.accents

        return VStack {
            // The theme first: which of the two looks below the gallery wears.
            SectionTitle("The theme")
            Picker(themes.map(\.scheme),
                   selection: Proxy(get: { application.colorScheme }, set: { application.colorScheme = $0 })) { scheme in
                themes.first { $0.scheme == scheme }?.name ?? ""
            }
                .accessibilityIdentifier("appearance.theme")
                .accessibilityLabel("Theme")

            // The accent the platform draws its controls in, where the user
            // chooses none for the system.
            SectionTitle("The accent")
            Picker(Array(accents.indices), selection: Proxy(
                get: { accents.firstIndex { $0.color == application.accentColor } ?? 0 },
                set: { application.accentColor = accents[$0].color })) { accents[$0].name }
                .accessibilityIdentifier("appearance.accent")
                .accessibilityLabel("Accent")

            #if WEB
            // The bars' buttons, which the Web draws itself.
            SectionTitle("The bars' buttons")
            Picker(Self.toolbarStyles.map(\.style), selection: Proxy(
                get: { style.toolbarStyle }, set: { style.toolbarStyle = $0 })) { chosen in
                Self.toolbarStyles.first { $0.style == chosen }?.name ?? ""
            }
                .accessibilityIdentifier("appearance.toolbarStyle")
                .accessibilityLabel("Buttons")
            // The application's own look for them: a style for every group and
            // every button on a bar, its states included (AppStyles.bars).
            Switch(Proxy(get: { style.barsInOwnLook }, set: { owns in
                style.barsInOwnLook = owns
                application.styles = AppStyles.sheet(barsInOwnLook: owns)
            }))
                .text("In the gallery's own look")
                .accessibilityIdentifier("appearance.barsInOwnLook")
            #endif

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
                + "and theme. A color, or the gradient the bars offer, paints the bars alone; "
                + "what the window shows behind the pages is its background. The sidebar stands on one material beside "
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

            Text("An accent of the application's own draws the controls where the user chooses none for the "
                + "system - the Web, the iPhone and the iPad, GNOME before 47; elsewhere the user's stands. "
                + "The bars' buttons - on glass, plain or rounded - are the Web's own to draw.")
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
        let name = title.lowercased()
        // Each surface's choices write that part of the theme's look.
        let surface = { (part: WritableKeyPath<ThemeLook, SurfaceLook>) in
            Proxy(get: { style[keyPath: key][keyPath: part] }, set: { style[keyPath: key][keyPath: part] = $0 })
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

            SurfacePickers(title: "The bars", label: "Bars", theme: name, part: .bar, surface: surface(\.bars))
            SurfacePickers(title: "The window", label: "Window", theme: name, part: .window, surface: surface(\.window))
            SurfacePickers(
                title: "The sidebar", label: "Sidebar", theme: name, part: .sidebar, surface: surface(\.sidebar))
            SurfacePickers(
                title: "The sidebar over the page", label: "Overlay", theme: name, part: .sidebarOverlay,
                surface: surface(\.sidebarOverlay))
        }
        .spacing(10)
    }
}

/// One surface's choices: what it is made of, in which color, and how thick
/// a blur.
private struct SurfacePickers: View {
    let title: String
    let label: String
    let theme: String
    let part: GallerySurface
    let surface: Proxy<SurfaceLook>

    var body: some View {
        let surface = self.surface
        let look = surface.wrappedValue
        let materials = SurfaceMaterial.offered(on: part)
        let accents = AccentChoice.allCases
        let blurs = SurfaceLook.blurs
        let id = "appearance.\(theme).\(label.lowercased())"

        return VStack {
            Text(title)
                .fontSize(12)
                .textColor(Palette.subtle)
            Picker(materials, selection: surface.material) {
                $0.name
            }
                .accessibilityIdentifier(id)
                .accessibilityLabel("\(label), \(theme)")
            Picker(accents, selection: surface.color) {
                $0.name
            }
                .accessibilityIdentifier("\(id)Color")
                .accessibilityLabel("\(label)'s color, \(theme)")
                .isEnabled(look.material.showsColor)
            Picker(blurs, selection: surface.blur) { blur in
                ["Ultra thin", "Thin", "Regular", "Thick", "Ultra thick"][blurs.firstIndex(of: blur) ?? 0]
            }
                .accessibilityIdentifier("\(id)Blur")
                .accessibilityLabel("\(label)'s blur, \(theme)")
                .isEnabled(look.material.showsBlur)
        }
        .spacing(10)
    }
}
// listing: end
