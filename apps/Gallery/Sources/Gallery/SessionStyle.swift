import StateUI

// listing: Gallery.SessionStyle
/// The kinds of window the galleries' scene opens beside its gallery windows -
/// each a window of that scene. See `GalleryScene`.
extension WindowType {
    /// The window that chooses the gallery's font.
    static let fonts = WindowType("gallery.fonts")

    /// The window that chooses the gallery's accent.
    static let colours = WindowType("gallery.colours")

    /// A window per swatch number - one kind, a window for each value.
    static let swatch = WindowType("gallery.swatch")
}
// listing: end

// listing: Gallery.SessionStyle
/// What the galleries' scene KEEPS with itself - handed back with it when the
/// system restores the application's windows, so the galleries come back in the
/// font and the colour they were left in.
extension SceneKey {
    /// The font the gallery's preview is set in.
    static let font = SceneKey("gallery.font", of: String.self)

    /// The gallery's look in the light theme and in the dark: its bars, and
    /// what its window and its sidebar are made of.
    static let lightLook = SceneKey("gallery.look.light", of: ThemeLook.self)
    static let darkLook = SceneKey("gallery.look.dark", of: ThemeLook.self)
}
// listing: end

// listing: Gallery.SessionStyle
/// A colour a gallery wears - on its bars, or behind its pages, where its look
/// asks for one.
enum AccentChoice: String, CaseIterable, PersistentValue {
    case gallery
    case system
    case violet
    case teal
    case coral
    case graphite

    /// The gallery's own colours, without the system's accent.
    static let own: [AccentChoice] = [.violet, .teal, .coral, .graphite]

    /// What the Colours window calls it.
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

    /// The colour on `surface`, the system's accent being `system` - one in
    /// both themes but the gallery's own, which is made for each part and
    /// theme.
    func color(system: Color, for surface: GallerySurface) -> Color {
        switch self {
        case .gallery: return surface.own
        case .system: return system
        case .violet: return AppColors.violet
        case .teal: return Color("#0F766E")
        case .coral: return Color("#C2410C")
        case .graphite: return Color("#374151")
        }
    }

    /// Whether words on the colour are the theme's own rather than white: the
    /// gallery's own colours are as light as the theme.
    var carriesThemesWords: Bool { self == .gallery }

    /// The colour with three fifths let through - a bar tinted over the
    /// platform's material.
    func translucentColor(system: Color, for surface: GallerySurface) -> Color {
        color(system: system, for: surface).opacity(0.4)
    }

    /// The colour laid over a blur - a seventh of an accent, the blur showing
    /// through it; most of the gallery's own, whose blur is its colour.
    func tint(system: Color, for surface: GallerySurface) -> Color {
        color(system: system, for: surface).opacity(self == .gallery ? Self.ownTint : 0.15)
    }

    /// How much of the gallery's own colour lies over a blur or glass: more on
    /// the iPad and the iPhone, whose glass is greyer, so that their sidebar
    /// wears the Mac's colour.
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
/// Fonts and Colours windows, so the Fonts and Colours windows change every
/// gallery window at once, with nothing passed between them.
final class SessionStyle {
    /// The font the preview is set in - empty for the platform's own.
    @State(sceneKey: .font) var font = ""

    /// The gallery's look in each theme - the one that suits the platform best,
    /// until the Appearance sample chooses another.
    @State(sceneKey: .lightLook) var lightLook = ThemeLook.light
    @State(sceneKey: .darkLook) var darkLook = ThemeLook.dark

    /// The look the gallery wears in a theme, `dark` or not.
    func look(dark: Bool) -> ThemeLook {
        dark ? darkLook : lightLook
    }

    /// Whether the Fonts and Colours windows hide while another scene is the
    /// one in front.
    @State var hidesTools = false

    /// Whether the Fonts and Colours windows float above the application's
    /// other windows rather than going under them.
    @State var floatsTools = false
}
// listing: end
