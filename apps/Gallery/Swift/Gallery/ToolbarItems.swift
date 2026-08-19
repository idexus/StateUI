// The button every page of the gallery carries.
//
// The MENU button is not here, and its absence is the lesson: a ToolbarItem is
// a TRAILING item on every platform, and a flyout that opens from the left with
// its button in the right corner reads as the wrong thing entirely. The gallery
// carries none of its own - MAUI draws the flyout toggle itself, in the leading
// slot on the ROOT of the stack, and a pushed page gives that slot to the back
// button. So the menu is reached from the root, and every other page is reached
// through it.

import StateUI

/// The gallery's home button - the StateUI type, given one more way to make
/// itself. It is declared here rather than in the library because there is
/// nothing general about it: it knows this app's state and this app's icon.
extension ToolbarItem {
    /// Back to the home page, for a page's `toolbarItems`.
    ///
    /// A page ADDS this to its own items rather than being handed a list, so a
    /// sample that declares toolbar items of its own keeps them - and it goes
    /// LAST, which is the end of the row the platform fills from the title
    /// outwards.
    ///
    /// The picture is the WHITE house in both themes, which is the one that
    /// reads on the violet bar `GalleryApp` paints - see the note in
    /// GalleryPage.swift on why a ToolbarItem's icon cannot be tinted and has to
    /// be chosen instead. The file is named for the theme it was drawn for; what
    /// decides here is the colour behind it, and that colour does not change.
    ///
    /// **One assignment, where this was three awaited calls.** Going home used
    /// to mean asking MAUI where it was, switching to `//home`, and then
    /// emptying the section just left by the name read on the way out - because
    /// the shell kept one stack per section and handed it back, so a switch
    /// alone left the sample the reader had been looking at sitting under that
    /// group's row. `nav.home()` sets the section and empties the path, and
    /// there is no other stack anywhere to go stale.
    static func home(_ nav: Navigation) -> ToolbarItem {
        ToolbarItem("Home")
            .id("home")
            .iconImageSource("nav_home_dark.png")
            .onClicked { nav.home() }
    }
}
