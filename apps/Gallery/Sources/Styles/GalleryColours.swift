// The gallery's own colour for each part of its window, made for each platform.

import StateUI

// listing: Gallery.Looks
/// A part of the gallery a colour paints - each has a colour of the gallery's
/// own, made to sit with the platform's look.
enum GallerySurface {
    case bar, window, sidebar, flyout

    /// The gallery's own colour for this part, in each theme: in the dark,
    /// the colours its Windows window wears in the gallery's violet acrylic -
    /// the window, the bar a breath lighter, the sidebar and the menu over the
    /// page as dark as a list of samples on it.
    var own: Color {
        switch self {
        case .bar: Color(light: Color("#EFEBFA"), dark: Color("#2E255A"))
        case .window: Color(light: Color("#F7F5FC"), dark: Color("#2A2154"))
        case .sidebar: Color(light: Color("#EEEBF6"), dark: Color("#251E4C"))
        case .flyout: Color(light: Color("#F7F5FC"), dark: Color("#251E4C"))
        }
    }
}
// listing: end
