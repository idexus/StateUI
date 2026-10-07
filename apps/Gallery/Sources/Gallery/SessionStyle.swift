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

    /// The colour of the gallery's bars.
    static let barColour = SceneKey("gallery.barColour", of: AccentChoice.self)

    /// The colour of what the gallery's windows show behind their pages.
    static let windowColour = SceneKey("gallery.windowColour", of: AccentChoice.self)

    /// What the gallery's bars are.
    static let bars = SceneKey("gallery.bars", of: BarLook.self)

    /// What the gallery's windows show behind their pages.
    static let windows = SceneKey("gallery.windows", of: WindowLook.self)
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

    /// The colour let through all but a seventh - a window's material tinted
    /// lightly, the material showing through it.
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

    /// What the gallery's bars are: clear, what stands behind them showing,
    /// until the Appearance sample chooses another look.
    @State(sceneKey: .bars) var bars = BarLook.clear

    /// The colour the bars are tinted or painted in.
    @State(sceneKey: .barColour) var barColour = AccentChoice.violet

    /// What the gallery's windows show behind their pages: the platform's
    /// own, until the Appearance sample chooses another look.
    @State(sceneKey: .windows) var windows = WindowLook.platform

    /// The colour the windows are tinted or painted in.
    @State(sceneKey: .windowColour) var windowColour = AccentChoice.violet

    /// The material the desktop shows through the windows in, where their look
    /// is one: the thickest until the Appearance sample chooses another.
    @State var material = Material.thick

    /// Whether the Fonts and Colours windows hide while another scene is the
    /// one in front.
    @State var hidesTools = false

    /// Whether the Fonts and Colours windows float above the application's
    /// other windows rather than going under them.
    @State var floatsTools = false
}
// listing: end
