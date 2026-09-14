// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What an arrangement can be told about itself.
//
// A view shown as a page is told through the `PageSession` its page holds. An
// arrangement - a `NavigationStack`, a `TabbedView`, a `SplitView` - is a page
// already, a value with no session of its own, so the two properties needed
// when another container presents it are modifiers on this protocol.

/// The identity shown for a constructed container page.
///
/// Written on a `NavigationStack`, a `TabbedView` or a `SplitView`, and read
/// where a page is shown as an ITEM of something else:
///
///     TabbedView(Tab.allCases) { tab in
///         switch tab {
///         case .home:
///             NavigationStack($homePath) {
///                 HomePage()
///             } destination: { … }
///             .title("Home")                    // the tab's caption
///             .iconImageSource("house.png")     // and its picture
///
///         case .settings:
///             SettingsPage()                    // a written page writes
///         }                                     // `page.title` instead
///     }
///
/// A page an author writes is told both through its session - see
/// `PageSession` in Types/PageSession.swift, where the same names carry the
/// same meaning and enter the host contract under the same keys.
public protocol PageElement: PropertyContainer {}

extension PageElement {
    /// What the page is called.
    ///
    /// Read wherever the page is shown as an ITEM of something else - the
    /// tab's caption on a `TabbedView` - and as the window's title where a
    /// platform takes one from the page.
    ///
    /// NOT the text on a navigation bar: that belongs to whichever page is on
    /// TOP of the stack, and a written page says it with `page.title`. A title
    /// on the `NavigationStack` itself names the whole stack.
    public func title(_ value: String) -> Modified {
        setValue(.title, .string(value))
    }

    /// The picture that stands for the page.
    ///
    /// A tab's icon, in practice: it is what a TabbedView draws above or beside
    /// the caption. A page that is not shown as an item of something else has
    /// nowhere to draw it, and platforms ignore it there.
    public func iconImageSource(_ value: ImageSource) -> Modified {
        setValue(.iconImageSource, value.propValue)
    }

}
