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

    /// What the gallery's bars are, in the light theme and in the dark.
    static let lightBars = SceneKey("gallery.light.bars", of: BarLook.self)
    static let darkBars = SceneKey("gallery.dark.bars", of: BarLook.self)

    /// The colour of the gallery's bars, in each theme.
    static let lightBarColour = SceneKey("gallery.light.barColour", of: AccentChoice.self)
    static let darkBarColour = SceneKey("gallery.dark.barColour", of: AccentChoice.self)

    /// What the gallery's windows show behind their pages, in each theme.
    static let lightWindows = SceneKey("gallery.light.windows", of: WindowLook.self)
    static let darkWindows = SceneKey("gallery.dark.windows", of: WindowLook.self)

    /// The colour of what the gallery's windows show behind their pages, in
    /// each theme.
    static let lightWindowColour = SceneKey("gallery.light.windowColour", of: AccentChoice.self)
    static let darkWindowColour = SceneKey("gallery.dark.windowColour", of: AccentChoice.self)
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

    /// What the gallery's bars are in the light theme, and in the dark: clear,
    /// what stands behind them showing, until the Appearance sample chooses
    /// another look.
    @State(sceneKey: .lightBars) var lightBars = BarLook.clear
    @State(sceneKey: .darkBars) var darkBars = BarLook.clear

    /// The colour the bars are tinted or painted in, in each theme.
    @State(sceneKey: .lightBarColour) var lightBarColour = AccentChoice.violet
    @State(sceneKey: .darkBarColour) var darkBarColour = AccentChoice.violet

    /// What the gallery's windows are made of: the platform's own in the light
    /// theme, a blur in a light tint in the dark.
    @State(sceneKey: .lightWindows) var lightWindows = WindowLook.platform
    @State(sceneKey: .darkWindows) var darkWindows = WindowLook.tintedBlur

    /// The colour the windows are tinted or painted in, in each theme.
    @State(sceneKey: .lightWindowColour) var lightWindowColour = AccentChoice.violet
    @State(sceneKey: .darkWindowColour) var darkWindowColour = AccentChoice.violet

    /// The blur the desktop shows through the windows in, in each theme, where
    /// their look is one: a thick one until the Appearance sample chooses
    /// another.
    @State var lightBlur = Blur.thick
    @State var darkBlur = Blur.thick

    /// The look the gallery wears in a theme, `dark` or not.
    func look(dark: Bool) -> ThemeLook {
        let keys = dark ? LookKeys.dark : LookKeys.light
        return ThemeLook(
            bars: self[keyPath: keys.bars], barColour: self[keyPath: keys.barColour],
            windows: self[keyPath: keys.windows], windowColour: self[keyPath: keys.windowColour],
            blur: self[keyPath: keys.blur])
    }

    /// Whether the Fonts and Colours windows hide while another scene is the
    /// one in front.
    @State var hidesTools = false

    /// Whether the Fonts and Colours windows float above the application's
    /// other windows rather than going under them.
    @State var floatsTools = false
}
// listing: end
