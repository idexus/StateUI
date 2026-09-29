// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The title and icon of an arrangement - a `NavigationStack`, a `TabbedView`
/// or a `SplitView` - read where it is shown as an item of something else,
/// such as a tab:
///
///     TabbedView(Tab.allCases) { tab in
///         switch tab {
///         case .home:
///             NavigationStack($homePath) {
///                 HomePage()
///             } destination: { … }
///             .title("Home")                    // the tab's caption
///             .icon("house.png")                // and its picture
///
///         case .settings:
///             SettingsPage()                    // a written page sets
///         }                                     // `page.title` instead
///     }
///
/// A page the author writes says the same through its `PageSession`.
public protocol PageElement: PropertyContainer {}

extension PageElement {
    /// What the page is called: a tab's caption, and the window's title where
    /// a platform takes one from the page.
    ///
    /// Not the text on a navigation bar, which belongs to the page on top of
    /// the stack; a title on the `NavigationStack` itself names the whole stack.
    public func title(_ value: String) -> Modified {
        setValue(PageElementContract.title, value)
    }

    /// The picture that stands for the page: a tab's icon. A page not shown as
    /// an item of something else has nowhere to draw it.
    public func icon(_ value: ImageSource) -> Modified {
        setValue(PageElementContract.icon, value)
    }

}
