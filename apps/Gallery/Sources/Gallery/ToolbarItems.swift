// The way home every page but home carries.
//
// The MENU button is not here: the native navigation surface owns a leading
// sidebar toggle on the root and gives that slot to the back button on pushed
// pages.

import StateUI

/// The gallery's home button - the StateUI type, given one more way to make
/// itself. It is declared here rather than in the library because there is
/// nothing general about it: it knows this app's state and this app's icon.
extension ToolbarItem {
    /// Back to the home page, in the gallery's group `MainPage` declares
    /// around every page.
    ///
    /// A page's own actions join that group's page rather than replacing it, so
    /// a sample that declares actions of its own keeps this one - and it stands
    /// at the edge, where it stays from page to page while a page's actions
    /// come in from the title's side.
    ///
    /// The picture is a pair, one for each theme, as the bar it stands on is
    /// the platform's own.
    ///
    /// **One assignment.** `nav.home()` sets the section and empties the path,
    /// and there is no other stack anywhere to go stale - the page the user
    /// was looking at does not linger under the group it came from.
    static func home(_ nav: Navigation) -> ToolbarItem {
        ToolbarItem("Home")
            .id("home")
            // THE ONE CONTROL ON EVERY PAGE, and the only way back from a
            // sample that does not go through the sidebar - so it is the handle
            // a script reaches for most. `.id` is the item's identity - the
            // differ's, and what an item declared further in takes this place
            // by; this is the platform's own.
            .accessibilityIdentifier("chrome.home")
            .icon(ImageSource(light: "nav_home.png", dark: "nav_home_dark.png"))
            .onClicked { nav.home() }
    }

}
