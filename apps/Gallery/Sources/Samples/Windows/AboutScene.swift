import StateUI

// listing: AboutScene
extension WindowType {
    /// About the gallery: one window for the whole application.
    static let about = WindowType("gallery.about")
}
// listing: end

// listing: AboutScene
/// About the gallery: one window for the whole application, in a scene of its
/// own. It belongs to no other scene, so it stands while the gallery's windows
/// open and close, and `application.openWindow(.about)` opens it from any of
/// them - or answers `WindowError.alreadyOpen`. See `ScenesSample`.
struct AboutScene: Scene {
    var body: some Scene {
        Window(.about) { AboutPage() }
    }
}
// listing: end
