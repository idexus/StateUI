// What every page of the gallery has in common.

import StateUI

/// A page you can be ON in the gallery.
///
/// It says two things once instead of six times: what the page is painted, and
/// that there is a way home in the corner of the bar. Which is why every one of
/// them carries `nav` - a page that can go home has to be able to move the
/// application, and moving it is writing state somebody else owns.
///
/// **What is NOT here: the bar.** A `NavigationPage` owns its bar - MAUI's own
/// model, where `BarBackgroundColor` belongs to the arrangement rather than to
/// a page on it - so the colours are written once, in `GalleryApp.detail`,
/// instead of being repeated by every page that appears under them. What a PAGE can
/// still ask of the stack it is on is the `navigationPage` properties: whether
/// there is a bar at all, whether there is a way back, what the back button
/// reads. `LevelPage` shows those.
///
/// The home button's picture is chosen for the colour behind it rather than
/// tinted: MAUI does NOT tint a ToolbarItem's icon - measured on Android, with a
/// white back arrow and a black house on the same bar - and the bar is the
/// violet `GalleryApp` paints, in both themes.
protocol GalleryPage: ContentPage {
    /// Where the gallery is, and how this page moves it.
    var nav: Navigation { get }
}

extension GalleryPage {
    /// The way home, in the top corner. A page with items of its own adds this
    /// to them rather than choosing between them - see `SamplePage`.
    var toolbarItems: [ToolbarItem] { [.home(nav)] }

    /// The bar's middle: the page's own title, drawn by the gallery rather
    /// than by MAUI.
    ///
    /// A title view REPLACES the title the platform would have drawn, which is
    /// the point - the words then wear the app's own size, weight and colour
    /// on every page and every platform, instead of whatever each platform
    /// gives a bar of this colour. `MenuTitle` is where that look is decided,
    /// once.
    var navigationPageTitleView: Element? { MenuTitle(title ?? "") }

    /// The page behind the content. MAUI: VisualElement.BackgroundColor.
    ///
    /// Tinted rather than white, which is what lets a card lift off it with a
    /// fill instead of a shadow - see `Palette.surface`.
    var backgroundColor: Color? { Palette.surface }
}
