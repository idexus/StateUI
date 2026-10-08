import StateUI

// listing: GalleryScene
/// The galleries - a SCENE: as many gallery windows as the user opens, and
/// the windows they open beside them, all sharing what the scene holds.
///
/// What the scene holds is the gallery's LOOK (`SessionStyle` - the font and
/// the accent its Fonts and Colours windows choose), handed to the gallery
/// windows and to the Fonts and Colours windows: nothing is passed between the
/// Colours window and the bars it paints.
/// What one gallery window is doing - where it is, its bar, its log, its
/// catalog - is that window's own: see Gallery/GalleryWindow.swift.
struct GalleryScene: Scene {
    /// What every gallery window looks like - kept with the scene. See
    /// SessionStyle.swift.
    @State private var style = SessionStyle()

    /// The scene's windows: the gallery windows, which launch and *File ▸ New
    /// Window* open; its Fonts and Colours windows, which read the scene's
    /// look and may step aside while another scene is in front or float above
    /// the application's other windows; its inspector; and a swatch per number.
    var body: some Scene {
        let style = self.style

        WindowGroup { GalleryWindow(style: style) }

        Window(.fonts) { FontsPage() }
            .hidesWhenInactive(style.hidesTools)
            .floatsOnTop(style.floatsTools)
            .environment(style)

        Window(.colours) { ColoursPage() }
            .hidesWhenInactive(style.hidesTools)
            .floatsOnTop(style.floatsTools)
            .environment(style)

        Window(.debugInspector) { DebugInspector() }

        WindowGroup(.swatch, for: Int.self) { number in SwatchPage(number: number) }
    }
}
// listing: end
