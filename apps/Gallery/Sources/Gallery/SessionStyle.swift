import StateUI

// listing: Gallery.SessionStyle
/// The kinds of window the galleries' scene opens beside its gallery windows -
/// each a window of that scene. See `GalleryScene`.
extension WindowType where Value == Void {
    /// The window that chooses the gallery's font.
    static let fonts = WindowType("gallery.fonts")

    /// The window that chooses the gallery's accent.
    static let colors = WindowType("gallery.colors")
}

extension WindowType where Value == Int {
    /// A window per swatch number - one kind, a window for each value.
    static let swatch = WindowType("gallery.swatch")
}
// listing: end

// listing: Gallery.SessionStyle
/// What the galleries' scene KEEPS with itself - handed back with it when the
/// system restores the application's windows, so the galleries come back in the
/// font and the color they were left in.
extension SceneKey where Value == String {
    /// The font the gallery's preview is set in.
    static let font = SceneKey("gallery.font")
}

extension SceneKey where Value == Bool {
    /// Whether the light theme's look is the user's own composition, and the dark's.
    static let lightComposed = SceneKey("gallery.look.light.composed")
    static let darkComposed = SceneKey("gallery.look.dark.composed")
}

extension SceneKey where Value == SurfaceMaterial {
    /// What each surface of each theme is made of.
    static let lightBarsMaterial = SceneKey("gallery.look.light.bars.material")
    static let lightWindowMaterial = SceneKey("gallery.look.light.window.material")
    static let lightSidebarMaterial = SceneKey("gallery.look.light.sidebar.material")
    static let lightSidebarOverlayMaterial = SceneKey("gallery.look.light.sidebarOverlay.material")
    static let darkBarsMaterial = SceneKey("gallery.look.dark.bars.material")
    static let darkWindowMaterial = SceneKey("gallery.look.dark.window.material")
    static let darkSidebarMaterial = SceneKey("gallery.look.dark.sidebar.material")
    static let darkSidebarOverlayMaterial = SceneKey("gallery.look.dark.sidebarOverlay.material")
}

extension SceneKey where Value == AccentChoice {
    /// The color each surface of each theme wears.
    static let lightBarsColor = SceneKey("gallery.look.light.bars.color")
    static let lightWindowColor = SceneKey("gallery.look.light.window.color")
    static let lightSidebarColor = SceneKey("gallery.look.light.sidebar.color")
    static let lightSidebarOverlayColor = SceneKey("gallery.look.light.sidebarOverlay.color")
    static let darkBarsColor = SceneKey("gallery.look.dark.bars.color")
    static let darkWindowColor = SceneKey("gallery.look.dark.window.color")
    static let darkSidebarColor = SceneKey("gallery.look.dark.sidebar.color")
    static let darkSidebarOverlayColor = SceneKey("gallery.look.dark.sidebarOverlay.color")
}

extension SceneKey where Value == Int {
    /// How thick a blur each surface of each theme is - its place in `SurfaceLook.blurs`.
    static let lightBarsBlur = SceneKey("gallery.look.light.bars.blur")
    static let lightWindowBlur = SceneKey("gallery.look.light.window.blur")
    static let lightSidebarBlur = SceneKey("gallery.look.light.sidebar.blur")
    static let lightSidebarOverlayBlur = SceneKey("gallery.look.light.sidebarOverlay.blur")
    static let darkBarsBlur = SceneKey("gallery.look.dark.bars.blur")
    static let darkWindowBlur = SceneKey("gallery.look.dark.window.blur")
    static let darkSidebarBlur = SceneKey("gallery.look.dark.sidebar.blur")
    static let darkSidebarOverlayBlur = SceneKey("gallery.look.dark.sidebarOverlay.blur")
}
// listing: end

// listing: Gallery.SessionStyle
/// A color a gallery wears - on its bars, or behind its pages, where its look
/// asks for one.
enum AccentChoice: String, CaseIterable, Codable {
    case gallery
    case system
    case violet
    case teal
    case coral
    case graphite

    /// The gallery's own colors, without the system's accent.
    static let own: [AccentChoice] = [.violet, .teal, .coral, .graphite]

    /// What the Colors window calls it.
    var name: String {
        switch self {
        case .gallery: return "The gallery's own"
        case .system: return "The system's accent"
        case .violet: return "Violet"
        case .teal: return "Teal"
        case .coral: return "Coral"
        case .graphite: return "Graphite"
        }
    }

    /// The color on `surface`, the system's accent being `system` - one in
    /// both themes but the gallery's own, which is made for each part and
    /// theme.
    func color(system: Color, for surface: GallerySurface) -> Color {
        switch self {
        case .gallery: return surface.own
        case .system: return system
        case .violet: return AppColors.violet
        case .teal: return Color(hex: 0x0F766E)
        case .coral: return Color(hex: 0xC2410C)
        case .graphite: return Color(hex: 0x374151)
        }
    }

    /// Whether words on the color are the theme's own rather than white: the
    /// gallery's own colors are as light as the theme.
    var carriesThemesWords: Bool { self == .gallery }

    /// The color laid over a blur - a seventh of an accent, the blur showing
    /// through it; most of the gallery's own, whose blur is its color.
    func tint(system: Color, for surface: GallerySurface) -> Color {
        color(system: system, for: surface).opacity(self == .gallery ? Self.ownTint : 0.15)
    }

    /// How much of the gallery's own color lies over a blur or glass: more on
    /// the iPad and the iPhone, whose glass is grayer, so that their sidebar
    /// wears the Mac's color.
    private static var ownTint: Double {
        #if UIKIT
        0.85
        #else
        0.7
        #endif
    }
}
// listing: end

// listing: Gallery.SessionStyle
/// What the galleries look like, and how their tool windows stand - stepping
/// aside for another scene, floating on top.
///
/// Held by the galleries' scene and handed to its gallery windows and to its
/// Fonts and Colors windows, so the Fonts and Colors windows change every
/// gallery window at once, with nothing passed between them.
@MainActor
final class SessionStyle {
    /// The font the preview is set in - empty for the platform's own.
    @State(sceneKey: .font) var font = ""

    /// Whether the light theme wears the user's composition, field by field, or the gallery's own look.
    @State(sceneKey: .lightComposed) var lightComposed = false

    /// What each surface of the light theme is made of, in which color, and how thick a blur.
    @State(sceneKey: .lightBarsMaterial)
    var lightBarsMaterial = ThemeLook.light.bars.material
    @State(sceneKey: .lightBarsColor)
    var lightBarsColor = ThemeLook.light.bars.color
    @State(sceneKey: .lightBarsBlur)
    var lightBarsBlur = SurfaceLook.place(of: ThemeLook.light.bars.blur)
    @State(sceneKey: .lightWindowMaterial)
    var lightWindowMaterial = ThemeLook.light.window.material
    @State(sceneKey: .lightWindowColor)
    var lightWindowColor = ThemeLook.light.window.color
    @State(sceneKey: .lightWindowBlur)
    var lightWindowBlur = SurfaceLook.place(of: ThemeLook.light.window.blur)
    @State(sceneKey: .lightSidebarMaterial)
    var lightSidebarMaterial = ThemeLook.light.sidebar.material
    @State(sceneKey: .lightSidebarColor)
    var lightSidebarColor = ThemeLook.light.sidebar.color
    @State(sceneKey: .lightSidebarBlur)
    var lightSidebarBlur = SurfaceLook.place(of: ThemeLook.light.sidebar.blur)
    @State(sceneKey: .lightSidebarOverlayMaterial)
    var lightSidebarOverlayMaterial = ThemeLook.light.sidebarOverlay.material
    @State(sceneKey: .lightSidebarOverlayColor)
    var lightSidebarOverlayColor = ThemeLook.light.sidebarOverlay.color
    @State(sceneKey: .lightSidebarOverlayBlur)
    var lightSidebarOverlayBlur = SurfaceLook.place(of: ThemeLook.light.sidebarOverlay.blur)

    /// Whether the dark theme wears the user's composition, field by field, or the gallery's own look.
    @State(sceneKey: .darkComposed) var darkComposed = false

    /// What each surface of the dark theme is made of, in which color, and how thick a blur.
    @State(sceneKey: .darkBarsMaterial)
    var darkBarsMaterial = ThemeLook.dark.bars.material
    @State(sceneKey: .darkBarsColor)
    var darkBarsColor = ThemeLook.dark.bars.color
    @State(sceneKey: .darkBarsBlur)
    var darkBarsBlur = SurfaceLook.place(of: ThemeLook.dark.bars.blur)
    @State(sceneKey: .darkWindowMaterial)
    var darkWindowMaterial = ThemeLook.dark.window.material
    @State(sceneKey: .darkWindowColor)
    var darkWindowColor = ThemeLook.dark.window.color
    @State(sceneKey: .darkWindowBlur)
    var darkWindowBlur = SurfaceLook.place(of: ThemeLook.dark.window.blur)
    @State(sceneKey: .darkSidebarMaterial)
    var darkSidebarMaterial = ThemeLook.dark.sidebar.material
    @State(sceneKey: .darkSidebarColor)
    var darkSidebarColor = ThemeLook.dark.sidebar.color
    @State(sceneKey: .darkSidebarBlur)
    var darkSidebarBlur = SurfaceLook.place(of: ThemeLook.dark.sidebar.blur)
    @State(sceneKey: .darkSidebarOverlayMaterial)
    var darkSidebarOverlayMaterial = ThemeLook.dark.sidebarOverlay.material
    @State(sceneKey: .darkSidebarOverlayColor)
    var darkSidebarOverlayColor = ThemeLook.dark.sidebarOverlay.color
    @State(sceneKey: .darkSidebarOverlayBlur)
    var darkSidebarOverlayBlur = SurfaceLook.place(of: ThemeLook.dark.sidebarOverlay.blur)

    /// The look the gallery wears in the light theme: the user's composition, or the gallery's own.
    var lightLook: ThemeLook {
        guard lightComposed else { return .light }

        return ThemeLook(
            bars: SurfaceLook(
                material: lightBarsMaterial, color: lightBarsColor, blur: SurfaceLook.blurs[lightBarsBlur]),
            window: SurfaceLook(
                material: lightWindowMaterial, color: lightWindowColor, blur: SurfaceLook.blurs[lightWindowBlur]),
            sidebar: SurfaceLook(
                material: lightSidebarMaterial, color: lightSidebarColor, blur: SurfaceLook.blurs[lightSidebarBlur]),
            sidebarOverlay: SurfaceLook(
                material: lightSidebarOverlayMaterial, color: lightSidebarOverlayColor,
                blur: SurfaceLook.blurs[lightSidebarOverlayBlur]))
    }

    /// The look the gallery wears in the dark theme: the user's composition, or the gallery's own.
    var darkLook: ThemeLook {
        guard darkComposed else { return .dark }

        return ThemeLook(
            bars: SurfaceLook(
                material: darkBarsMaterial, color: darkBarsColor, blur: SurfaceLook.blurs[darkBarsBlur]),
            window: SurfaceLook(
                material: darkWindowMaterial, color: darkWindowColor, blur: SurfaceLook.blurs[darkWindowBlur]),
            sidebar: SurfaceLook(
                material: darkSidebarMaterial, color: darkSidebarColor, blur: SurfaceLook.blurs[darkSidebarBlur]),
            sidebarOverlay: SurfaceLook(
                material: darkSidebarOverlayMaterial, color: darkSidebarOverlayColor,
                blur: SurfaceLook.blurs[darkSidebarOverlayBlur]))
    }

    /// One color on every surface of both themes, which makes both looks the user's composition.
    func wearColor(_ accent: AccentChoice) {
        lightBarsColor = accent
        lightWindowColor = accent
        lightSidebarColor = accent
        lightSidebarOverlayColor = accent
        darkBarsColor = accent
        darkWindowColor = accent
        darkSidebarColor = accent
        darkSidebarOverlayColor = accent
        lightComposed = true
        darkComposed = true
    }

    /// Back to the gallery's own look in a theme, `dark` or not: the next composition starts from it.
    func wearOwnLook(dark: Bool) {
        let own = dark ? ThemeLook.dark : ThemeLook.light
        if !dark {
            lightComposed = false
            lightBarsMaterial = own.bars.material
            lightBarsColor = own.bars.color
            lightBarsBlur = SurfaceLook.place(of: own.bars.blur)
            lightWindowMaterial = own.window.material
            lightWindowColor = own.window.color
            lightWindowBlur = SurfaceLook.place(of: own.window.blur)
            lightSidebarMaterial = own.sidebar.material
            lightSidebarColor = own.sidebar.color
            lightSidebarBlur = SurfaceLook.place(of: own.sidebar.blur)
            lightSidebarOverlayMaterial = own.sidebarOverlay.material
            lightSidebarOverlayColor = own.sidebarOverlay.color
            lightSidebarOverlayBlur = SurfaceLook.place(of: own.sidebarOverlay.blur)
        }
        if dark {
            darkComposed = false
            darkBarsMaterial = own.bars.material
            darkBarsColor = own.bars.color
            darkBarsBlur = SurfaceLook.place(of: own.bars.blur)
            darkWindowMaterial = own.window.material
            darkWindowColor = own.window.color
            darkWindowBlur = SurfaceLook.place(of: own.window.blur)
            darkSidebarMaterial = own.sidebar.material
            darkSidebarColor = own.sidebar.color
            darkSidebarBlur = SurfaceLook.place(of: own.sidebar.blur)
            darkSidebarOverlayMaterial = own.sidebarOverlay.material
            darkSidebarOverlayColor = own.sidebarOverlay.color
            darkSidebarOverlayBlur = SurfaceLook.place(of: own.sidebarOverlay.blur)
        }
    }

    /// The look the gallery wears in a theme, `dark` or not.
    func look(dark: Bool) -> ThemeLook {
        dark ? darkLook : lightLook
    }

    /// How the bars' buttons stand where the host draws them itself: on glass
    /// on the Web, the gallery's own look for them.
    @State var toolbarStyle = SessionStyle.ownToolbarStyle

    /// Whether the bars' buttons stand in the gallery's own look, where the
    /// host draws them itself (`AppStyles.sheet(barsInOwnLook:)`).
    @State var barsInOwnLook = false

    /// The gallery's own look for the bars' buttons: glass on the Web, the
    /// platform's own elsewhere.
    static var ownToolbarStyle: ToolbarStyle {
        #if WEB
        .glass
        #else
        .system
        #endif
    }

    /// Whether the Fonts and Colors windows hide while another scene is the
    /// one in front.
    @State var hidesTools = false

    /// Whether the Fonts and Colors windows float above the application's
    /// other windows rather than going under them.
    @State var floatsTools = false
}
// listing: end
