// What the gallery puts in the middle of the bar.

import StateUI

/// The page's title, in the gallery's own hand - a `NavigationPage` title view.
///
/// It draws the title and nothing else. The native navigation surface owns the
/// leading flyout or back affordance, so this view does not duplicate one.
///
/// What it is for is the LOOK. A title view replaces the title the platform
/// would have drawn, so the words wear one size, weight and colour on every
/// page and every platform - decided here, once.
struct MenuTitle: ContentView {
    /// What the page is called, drawn here because a title view replaces the
    /// standard title.
    private let title: String

    /// - Parameter title: What the page is called.
    init(_ title: String) {
        self.title = title
    }

    var content: any View {
        Label(title)
            .fontSize(17)
            .fontAttributes(.bold)
            .textColor(Palette.onBrand)
            .verticalOptions(.center)
    }
}
