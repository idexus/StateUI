// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The bar over what an arrangement shows. It belongs to the arrangement and
/// looks the same whichever page shows; what one page asks of the bar - to be
/// hidden, or to carry a view instead of its title - its view says of its page,
/// `.showsNavigationBar(false)`.
///
/// Declared on a window's page, it is the whole window's bar; an arrangement
/// further in stands in its place, one value at a time, while it is shown:
///
///     SplitView($showsMenu) {
///         MenuPage()
///     } detail: {
///         NavigationStack($path) { … }
///             .barBackgroundColor(.cornflowerBlue)
///     }
///     .barTitle("Notes")
///     .barSubtitle(folder.name)
///
/// A split view's bar is both its panes': a sidebar with a bar of its own
/// wears what its split view declares, and nothing from around it. A sheet
/// takes nothing from around it.
public protocol BarElement: PropertyContainer {}

extension BarElement {
    /// What the bar is painted, in one flat colour.
    ///
    ///     NavigationStack($path) {
    ///         HomePage()
    ///     } destination: { route in
    ///         DetailPage(route)
    ///     }
    ///     .barBackgroundColor(.cornflowerBlue)
    ///
    /// Leave it unwritten to retain the native material and appearance.
    public func barBackgroundColor(_ value: Color) -> Modified {
        setValue(BarElementContract.barBackgroundColor, value)
    }

    /// The colour of what stands on the bar: the title and the native
    /// navigation and toolbar affordances. Destructive actions keep the
    /// platform's warning colour.
    public func barForegroundColor(_ value: Color) -> Modified {
        setValue(BarElementContract.barForegroundColor, value)
    }

    /// The application's name in the bar, where the platform's desktop chrome
    /// names the application. The visible page's title still names the
    /// window to the system.
    public func barTitle(_ value: String) -> Modified {
        setValue(BarElementContract.barTitle, value)
    }

    /// A second line in the bar, under the title it shows: the current
    /// document or section. An empty one is none.
    public func barSubtitle(_ value: String) -> Modified {
        setValue(BarElementContract.barSubtitle, value)
    }

    /// The application's mark beside its name in the bar.
    public func barIcon(_ value: ImageSource) -> Modified {
        setValue(BarElementContract.barIcon, value)
    }
}
