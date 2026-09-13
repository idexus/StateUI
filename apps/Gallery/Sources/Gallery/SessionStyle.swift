import StateUI

/// The kinds of window a gallery opens beside its main one - each a window of
/// the gallery that opened it. See `GalleryScene`.
extension WindowType {
    /// The window that chooses the gallery's font.
    static let fonts = WindowType("gallery.fonts")

    /// The window that chooses the gallery's accent.
    static let colours = WindowType("gallery.colours")

    /// A window per swatch number - one kind, a window for each value.
    static let swatch = WindowType("gallery.swatch")
}

/// What one gallery KEEPS with itself - handed back with it when the system
/// restores the application's windows, so each gallery comes back in the font
/// and the colour it was left in.
extension SceneKey {
    /// The font the gallery's preview is set in.
    static let font = SceneKey("gallery.font", of: String.self)

    /// The gallery's accent.
    static let accent = SceneKey("gallery.accent", of: AccentChoice.self)
}

/// An accent a gallery can wear - the colour its bars are painted in.
enum AccentChoice: String, CaseIterable, PersistentValue {
    case violet
    case teal
    case coral
    case graphite

    /// What the Colours window calls it.
    var name: String {
        switch self {
        case .violet: return "Violet"
        case .teal: return "Teal"
        case .coral: return "Coral"
        case .graphite: return "Graphite"
        }
    }

    /// The colour - one in both themes, since everything on the bars it
    /// paints is white either way.
    var color: Color {
        switch self {
        case .violet: return AppColors.violet
        case .teal: return Color("#0F766E")
        case .coral: return Color("#C2410C")
        case .graphite: return Color("#374151")
        }
    }
}

/// What one gallery looks like, and how its tool windows stand - stepping
/// aside for another gallery, floating on top - the context a gallery's
/// windows share.
///
/// Held by the gallery's scene and offered to every window of it, so the Fonts
/// and Colours windows change the gallery that opened them and no other, with
/// nothing passed between them and the main window.
final class SessionStyle {
    /// The font the preview is set in - empty for the platform's own.
    @State(sceneKey: .font) var font = ""

    /// The accent the gallery's bars are painted in.
    @State(sceneKey: .accent) var accent = AccentChoice.violet

    /// Whether the Fonts and Colours windows hide while another gallery is the
    /// one in front.
    @State var hidesTools = false

    /// Whether the Fonts and Colours windows float above the gallery's main
    /// window rather than going under it.
    @State var floatsTools = false
}
