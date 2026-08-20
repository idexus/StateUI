// What the gallery puts in the middle of the bar.

import StateUI

/// The page's title, in the gallery's own hand - a `NavigationPage` title view.
///
/// It draws the TITLE and nothing else. There is no menu button here: MAUI puts
/// its own flyout toggle in the leading slot on the root of the stack, and a
/// pushed page gives that slot to the back button, so a second one would be two
/// ways to do one thing on one bar.
///
/// What it is for is the LOOK. A title view replaces the title the platform
/// would have drawn, so the words wear one size, weight and colour on every
/// page and every platform - decided here, once.
struct MenuTitle: ContentView {
    /// What the page is called, drawn here because a title view REPLACES the
    /// title MAUI would have drawn.
    private let title: String

    /// - Parameter title: What the page is called.
    init(_ title: String) {
        self.title = title
    }

    var content: Element {
        Label(title)
            .fontSize(17)
            .fontAttributes(.bold)
            .textColor(Palette.onBrand)
            .verticalOptions(.center)
    }
}
