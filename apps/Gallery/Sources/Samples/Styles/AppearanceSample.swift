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
            Picker(themes.map(\.scheme), selection: application.$colorScheme) { scheme in
                themes.first { $0.scheme == scheme }?.name ?? ""
            }
                .accessibilityIdentifier("appearance.theme")
                .accessibilityLabel("Theme")

            // The accent the platform draws its controls in, where the user
            // chooses none for the system.
            SectionTitle("The accent")
            Picker(accents.map(\.color), selection: application.$accentColor) { color in
                accents.first { $0.color == color }?.name ?? ""
            }
                .accessibilityIdentifier("appearance.accent")
                .accessibilityLabel("Accent")

            #if WEB
            // The bars' buttons, which the Web draws itself.
            SectionTitle("The bars' buttons")
            Picker(Self.toolbarStyles.map(\.style), selection: style.$toolbarStyle) { chosen in
                Self.toolbarStyles.first { $0.style == chosen }?.name ?? ""
            }
                .accessibilityIdentifier("appearance.toolbarStyle")
                .accessibilityLabel("Buttons")
            // The application's own look for them: a style for every group and
            // every button on a bar, its states included (AppStyles.bars).
            Switch(style.$barsInOwnLook)
                .text("In the gallery's own look")
                .accessibilityIdentifier("appearance.barsInOwnLook")
                .onToggled { owns in application.styles = AppStyles.sheet(barsInOwnLook: owns) }
            #endif

            // A look for each theme: the gallery wears the one of the theme in
            // force, and changes with it. Side by side where there is room,
            // one under the other on a phone.
            if device.info.formFactor == .phone {
                LookColumn(title: "Light", dark: false, style: style)
                LookColumn(title: "Dark", dark: true, style: style)
            } else {
                Grid {
                    LookColumn(title: "Light", dark: false, style: style)
                        .gridColumn(0)
                    LookColumn(title: "Dark", dark: true, style: style)
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
/// sidebar over the page are made of - each field a state the scene keeps,
/// written by its picker, which makes the look the user's own.
private struct LookColumn: View {
    let title: String
    let dark: Bool
    let style: SessionStyle

    var body: some View {
        let (style, dark) = (self.style, self.dark)
        let name = title.lowercased()
        let composed = dark ? style.$darkComposed : style.$lightComposed

        return VStack {
            SectionTitle(title)

            // Back to the look this gallery draws on this platform, whatever
            // it was when the user composed another.
            Button("The gallery's own")
                .accessibilityIdentifier("appearance.\(name).own")
                .isEnabled(composed.wrappedValue)
                .onClicked { style.wearOwnLook(dark: dark) }

            SurfacePickers(
                title: "The bars", label: "Bars", theme: name, part: .bar, composed: composed,
                material: dark ? style.$darkBarsMaterial : style.$lightBarsMaterial,
                color: dark ? style.$darkBarsColor : style.$lightBarsColor,
                blur: dark ? style.$darkBarsBlur : style.$lightBarsBlur)
            SurfacePickers(
                title: "The window", label: "Window", theme: name, part: .window, composed: composed,
                material: dark ? style.$darkWindowMaterial : style.$lightWindowMaterial,
                color: dark ? style.$darkWindowColor : style.$lightWindowColor,
                blur: dark ? style.$darkWindowBlur : style.$lightWindowBlur)
            SurfacePickers(
                title: "The sidebar", label: "Sidebar", theme: name, part: .sidebar, composed: composed,
                material: dark ? style.$darkSidebarMaterial : style.$lightSidebarMaterial,
                color: dark ? style.$darkSidebarColor : style.$lightSidebarColor,
                blur: dark ? style.$darkSidebarBlur : style.$lightSidebarBlur)
            SurfacePickers(
                title: "The sidebar over the page", label: "Overlay", theme: name, part: .sidebarOverlay,
                composed: composed,
                material: dark ? style.$darkSidebarOverlayMaterial : style.$lightSidebarOverlayMaterial,
                color: dark ? style.$darkSidebarOverlayColor : style.$lightSidebarOverlayColor,
                blur: dark ? style.$darkSidebarOverlayBlur : style.$lightSidebarOverlayBlur)
        }
        .spacing(10)
    }
}

/// One surface's choices: what it is made of, in which color, and how thick
/// a blur - each a state of its own; a choice makes the theme's look the
/// user's composition.
private struct SurfacePickers: View {
    let title: String
    let label: String
    let theme: String
    let part: GallerySurface
    let composed: Binding<Bool>
    let material: Binding<SurfaceMaterial>
    let color: Binding<AccentChoice>
    let blur: Binding<Int>

    var body: some View {
        let composed = self.composed
        let made = material.wrappedValue
        let blurs = ["Ultra thin", "Thin", "Regular", "Thick", "Ultra thick"]
        let id = "appearance.\(theme).\(label.lowercased())"

        return VStack {
            Text(title)
                .fontSize(12)
                .textColor(Palette.subtle)
            Picker(SurfaceMaterial.offered(on: part), selection: material) {
                $0.name
            }
                .accessibilityIdentifier(id)
                .accessibilityLabel("\(label), \(theme)")
                .onSelectedIndexChanged { _ in composed.wrappedValue = true }
            Picker(AccentChoice.allCases, selection: color) {
                $0.name
            }
                .accessibilityIdentifier("\(id)Color")
                .accessibilityLabel("\(label)'s color, \(theme)")
                .isEnabled(made.showsColor)
                .onSelectedIndexChanged { _ in composed.wrappedValue = true }
            Picker(Array(SurfaceLook.blurs.indices), selection: blur) { blurs[$0] }
                .accessibilityIdentifier("\(id)Blur")
                .accessibilityLabel("\(label)'s blur, \(theme)")
                .isEnabled(made.showsBlur)
                .onSelectedIndexChanged { _ in composed.wrappedValue = true }
        }
        .spacing(10)
    }
}
// listing: end
