// What every page of the gallery has in common.

import StateUI

extension PageSession {
    /// Dresses a page the way every page of the gallery is dressed: its title
    /// in the gallery's own hand on the bar, the inspector and the way home in
    /// the corner, and the tinted ground behind the content.
    ///
    ///     VStack { … }
    ///         .onCreated { page.gallery("Level 2", scene: scene, nav: nav) }
    ///
    /// Said once here instead of on every page. **What is NOT here is the
    /// bar**: a `NavigationPage` owns its bar - MAUI's own model, where
    /// `BarBackgroundColor` belongs to the arrangement rather than to a page on
    /// it - so the colours are written once, in `MainWindow.detail`. What a
    /// PAGE can still ask of the stack it is on is the `navigationPage`
    /// properties - whether there is a bar at all, whether there is a way back,
    /// what the back button reads - and `LevelPage` shows those.
    ///
    /// The title view REPLACES the title the platform would have drawn, which
    /// is the point: the words wear the app's own size, weight and colour on
    /// every page and every platform, and `MenuTitle` is where that look is
    /// decided, once. The home button's picture is chosen for the colour behind
    /// it rather than tinted: MAUI does NOT tint a ToolbarItem's icon -
    /// measured on Android, with a white back arrow and a black house on the
    /// same bar - and the bar is the gallery's accent, a dark colour whichever
    /// is chosen. A page with buttons of its own puts them BEFORE these, from
    /// its own `.onCreated` - see `ToolbarSample`.
    ///
    /// - Parameters:
    ///   - title: what the page is called.
    ///   - scene: the gallery the page is in - the scene its ⓘ opens the
    ///     inspector of.
    ///   - nav: where the gallery is, which the way home moves - nil on the
    ///     home page, which is where it goes.
    func gallery(_ title: String, scene: SceneSession, nav: Navigation?) {
        self.title = title
        navigationPageTitleView = MenuTitle(title)
        toolbarItems = [.inspector(scene)] + (nav.map { [.home($0)] } ?? [])

        // Tinted rather than white, which is what lets a card lift off it with
        // a fill instead of a shadow - see `Palette.surface`.
        backgroundColor = Palette.surface
    }
}
