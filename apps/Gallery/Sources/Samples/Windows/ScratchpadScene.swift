import StateUI

// listing: ScratchpadScene
extension WindowType {
    /// A scratchpad window: as many as the user opens.
    static let scratchpad = WindowType("gallery.scratchpad")
}
// listing: end

// listing: ScratchpadScene
/// What the scratchpads KEEP - handed back with their scene when the system restores the application's windows.
extension SceneKey {
    /// The scratchpads' text.
    static let scratch = SceneKey("gallery.scratch", of: String.self)
}
// listing: end

// listing: ScratchpadScene
/// The scratchpads: a scene of their own beside the galleries, its windows as many as
/// `application.openWindow(.scratchpad)` opens - each showing the scene's one text. See `ScenesSample`.
struct ScratchpadScene: Scene {
    var body: some Scene {
        WindowGroup(.scratchpad) { ScratchpadPage() }
    }
}
// listing: end
