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
    static let lightLook = SceneKey("gallery.light.look", of: ThemeLook.self)
    static let darkLook = SceneKey("gallery.dark.look", of: ThemeLook.self)
}
// listing: end

// listing: Gallery.SessionStyle
/// A colour a gallery wears - on its bars, or behind its pages, where its look
/// asks for one.
enum AccentChoice: String, CaseIterable, PersistentValue {
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
        case .system: return "The system's accent"
        case .violet: return "Violet"
        case .teal: return "Teal"
        case .coral: return "Coral"
        case .graphite: return "Graphite"
        }
    }

    /// The colour, the system's accent being `system` - one in both themes,
    /// since everything on the bars it paints is white either way.
    func color(system: Color) -> Color {
        switch self {
        case .system: return system
        case .violet: return AppColors.violet
        case .teal: return Color("#0F766E")
        case .coral: return Color("#C2410C")
        case .graphite: return Color("#374151")
        }
    }

    /// The colour with three fifths let through - a bar tinted over the
    /// platform's material.
    func translucentColor(system: Color) -> Color {
        color(system: system).opacity(0.4)
    }

    /// The colour let through all but a seventh - a window's blur tinted
    /// lightly, the blur showing through it.
    func tint(system: Color) -> Color {
        color(system: system).opacity(0.15)
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

    /// The gallery's look in the light theme: clear bars, and the platform's
    /// own window and sidebar - until the Appearance sample chooses another.
    @State(sceneKey: .lightLook) var lightLook = ThemeLook(
        bars: .clear, barColour: .violet, window: .platform, sidebar: .platform, flyout: .platform)

    /// The gallery's look in the dark theme: clear bars over a window of a
    /// lightly tinted blur, the sidebar the platform's own.
    @State(sceneKey: .darkLook) var darkLook = ThemeLook(
        bars: .clear, barColour: .violet,
        window: SurfaceLook(material: .tintedBlur, colour: .violet, blur: .thick),
        sidebar: .platform, flyout: .platform)

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
