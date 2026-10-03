// What every page of the gallery has in common.

import StateUI

extension View {
    /// Dresses the page this view stands on the way every page of the gallery
    /// is dressed: its title and the tinted ground behind the content.
    ///
    ///     VStack { … }
    ///         .galleryPage("Level 2")
    ///
    /// Said once here instead of on every page. **What is NOT here is the
    /// bar**: a `NavigationStack` owns its bar, so its appearance is written
    /// once in `MainPage.detail`, and the inspector and the way home stand
    /// on every page because `MainPage` declares them once, around all of
    /// them. What a PAGE can still ask of the stack it is on - whether there
    /// is a bar at all, whether there is a way back, what the back button
    /// reads - its view says too, and `LevelPage` shows those.
    ///
    /// The title is the page's own, drawn by each platform's bar in its own
    /// type. A page with actions of its own declares them with `.toolbar { }`,
    /// and they stand nearer the title than the gallery's; see `ToolbarSample`.
    ///
    /// - Parameter title: what the page is called.
    func galleryPage(_ title: String) -> some View {
        // Tinted rather than white, which is what lets a card lift off it with
        // a fill instead of a shadow - see `Palette.surface`.
        self.title(title).pageBackground(Palette.surface)
    }
}
