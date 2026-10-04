import StateUI

extension WindowType {
    /// About the gallery: one window for the whole application.
    static let about = WindowType("gallery.about")
}

/// About the gallery: one window for the whole application, in a scene of its
/// own. It belongs to no gallery window, so it stands while they open and
/// close, and `application.openWindow(.about)` finds it from any of them. See
/// `ScenesSample`.
struct AboutScene: Scene {
    var body: some Scene {
        Window(.about) { AboutPage() }
    }
}
