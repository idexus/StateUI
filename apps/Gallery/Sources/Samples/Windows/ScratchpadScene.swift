import StateUI

/// The gallery's kinds of scene beside its galleries - each named by its main window. See `SceneKindsSample`.
extension WindowType {
    /// A scratchpad: a kind of scene of its own, as many as the user opens.
    static let scratchpad = WindowType("gallery.scratchpad")

    /// About the gallery: one window for the whole application.
    static let about = WindowType("gallery.about")
}

/// What one scratchpad KEEPS with itself - handed back with it when the system restores the application's windows.
extension SceneKey {
    /// The scratchpad's text.
    static let scratch = SceneKey("gallery.scratch", of: String.self)
}

/// A scratchpad: a kind of scene of its own beside the galleries, its main window naming it - each one opened by
/// `application.openWindow(.scratchpad)`, with a text of its own.
struct ScratchpadScene: Scene {
    var body: some Scene {
        WindowGroup(.scratchpad) { ScratchpadPage() }
    }
}
