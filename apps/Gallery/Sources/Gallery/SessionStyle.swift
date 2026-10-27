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

extension SceneKey where Value == LookChoice {
    /// The look chosen for the light theme and for the dark: the gallery's own,
    /// or one the user composed.
    static let lightLook = SceneKey("gallery.look.light")
    static let darkLook = SceneKey("gallery.look.dark")
}
// listing: end

// listing: Gallery.SessionStyle
/// A color a gallery wears - on its bars, or behind its pages, where its look
/// asks for one.
enum AccentChoice: String, CaseIterable {
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

    /// The look chosen for each theme - the gallery's own, until the
    /// Appearance sample composes another.
    @State(sceneKey: .lightLook) var lightChoice = LookChoice.own
    @State(sceneKey: .darkLook) var darkChoice = LookChoice.own

    /// The look the gallery wears in the light theme; a look written here is
    /// the user's own composition.
    var lightLook: ThemeLook {
        get { lightChoice.look(dark: false) }
        set { lightChoice = .composed(newValue) }
    }

    /// The look the gallery wears in the dark theme; a look written here is
    /// the user's own composition.
    var darkLook: ThemeLook {
        get { darkChoice.look(dark: true) }
        set { darkChoice = .composed(newValue) }
    }

    /// The look the gallery wears in a theme, `dark` or not.
    func look(dark: Bool) -> ThemeLook {
        dark ? darkLook : lightLook
    }

    /// How the bars' buttons stand where the host draws them itself: on glass
    /// on the Web, the gallery's own look for them.
    @State var toolbarStyle = SessionStyle.ownToolbarStyle

    /// Whether the bars' buttons stand on the accent's tint.
    @State var tintsBarButtons = false

    /// The weight of the words on the bars' buttons; nil for the platform's own.
    @State var barButtonWeight: FontWeight?

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
