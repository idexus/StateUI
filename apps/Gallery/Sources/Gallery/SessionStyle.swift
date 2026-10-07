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

    /// The gallery's accent.
    static let accent = SceneKey("gallery.accent", of: AccentChoice.self)
}
// listing: end

// listing: Gallery.SessionStyle
/// An accent a gallery can wear: the platform's own, its bars as the platform
/// draws them, or a colour its bars are painted in.
enum AccentChoice: String, CaseIterable, PersistentValue {
    case platform
    case violet
    case teal
    case coral
    case graphite

    /// What the Colours window calls it.
    var name: String {
        switch self {
        case .platform: return "The platform's own"
        case .violet: return "Violet"
        case .teal: return "Teal"
        case .coral: return "Coral"
        case .graphite: return "Graphite"
        }
    }

    /// The colour - one in both themes, since everything on the bars it
    /// paints is white either way; nil for the platform's own.
    var color: Color? {
        switch self {
        case .platform: return nil
        case .violet: return AppColors.violet
        case .teal: return Color("#0F766E")
        case .coral: return Color("#C2410C")
        case .graphite: return Color("#374151")
        }
    }

    /// The colour with three fifths let through - what a window the desktop
    /// shows through is tinted with, thin enough for the desktop to show; nil
    /// for the platform's own.
    var translucentColor: Color? {
        switch self {
        case .platform: return nil
        case .violet: return Color("#66512BD4")
        case .teal: return Color("#660F766E")
        case .coral: return Color("#66C2410C")
        case .graphite: return Color("#66374151")
        }
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

    /// The gallery's accent: the platform's own until the Colours window
    /// chooses another.
    @State(sceneKey: .accent) var accent = AccentChoice.platform

    /// Whether the Fonts and Colours windows hide while another scene is the
    /// one in front.
    @State var hidesTools = false

    /// Whether the Fonts and Colours windows float above the application's
    /// other windows rather than going under them.
    @State var floatsTools = false
}
// listing: end
