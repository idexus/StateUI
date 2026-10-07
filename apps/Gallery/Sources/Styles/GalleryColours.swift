// The gallery's own colour for each part of its window, made for each platform.

import StateUI

// listing: Gallery.Looks
/// A part of the gallery a colour paints - each has a colour of the gallery's
/// own, made to sit with the platform's look.
enum GallerySurface {
    case bar, window, sidebar, flyout

    /// The gallery's own colour for this part, in each theme: the violet its
    /// windows wear, lit or darkened a breath for each part, so the sidebar
    /// and the menu over the page read as the window's own.
    var own: Color {
        switch self {
        case .bar: Color(light: Color("#EFEBFA"), dark: Color("#251F3D"))
        case .window: Color(light: Color("#F7F5FC"), dark: Color("#211C34"))
        case .sidebar: Color(light: Color("#EEEBF6"), dark: Color("#1B1729"))
        case .flyout: Color(light: Color("#F7F5FC"), dark: Color("#1E1A2E"))
        }
    }
}
// listing: end
