// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a page that is CONSTRUCTED can be told about itself.
//
// There are two kinds of page in this library, and the difference is who writes
// the type. A page an author WRITES conforms to `ContentPage` and answers
// properties - `var title: String? { "Home" }` - which is the shape a protocol
// with a dozen defaults wants. A page an author CONSTRUCTS is a value the
// library declares: `NavigationPage($path) { … }`, `TabbedPage(tabs) { … }`,
// `FlyoutPage($menu) { … } detail: { … }`. All three wear this protocol.
// A constructor's result has no properties to override, so what it is told is
// told by modifiers - `NavigationPage($path) { … }.title("Stack")`.
//
// This tier is the three properties a CONTAINER page still needs: what it is
// called, what it is drawn as - which is what a tab caption and a tab icon are
// read from when the page inside a tab is a whole navigation stack - and how it
// covers the screen when it is presented. They are exactly the three the host
// applies to any page it makes (`ApplyPageChrome` in SwiftPages.cs); the other
// twelve reach a content page alone, and are declared on `ContentPage`.
//
// So this is THE WHOLE of what a constructed page can be told, not a corner of
// it. `Page` next door declares nothing at all: a property there would be one a
// `NavigationPage` wears and can never answer - always nil, beside a modifier of
// the same name that works.
//
// Not called `Page`, obviously - that name is the marker every page wears, one
// file over in Application.swift. Both stand for MAUI's Page class; they are
// the two ways of reaching it.

/// The properties MAUI's `Page` declares that a container page is given by
/// modifier rather than by conformance. MAUI: Page.
///
/// Written on a `NavigationPage`, a `TabbedPage` or a `FlyoutPage`, and read
/// where a page is shown as an ITEM of something else:
///
///     TabbedPage(Tab.allCases) { tab in
///         switch tab {
///         case .home:
///             NavigationPage($homePath) {
///                 HomePage()
///             } destination: { … }
///             .title("Home")                    // the tab's caption
///             .iconImageSource("house.png")     // and its picture
///
///         case .settings:
///             SettingsPage()                    // a written page says
///         }                                     // `var title` instead
///     }
///
/// A page an author writes answers all three as properties of its own - see
/// `ContentPage` in Views/Application.swift, where the same names carry the
/// same meaning and arrive on the wire as the same keys.
public protocol PageElement: PropertyContainer {}

extension PageElement {
    /// What the page is called. MAUI: Page.Title.
    ///
    /// Read wherever the page is shown as an ITEM of something else - the
    /// tab's caption on a `TabbedPage` - and as the window's title where a
    /// platform takes one from the page.
    ///
    /// NOT the text on a navigation bar: that belongs to whichever page is on
    /// TOP of the stack, and a written page says it with `var title`. A title
    /// on the `NavigationPage` itself names the whole stack.
    public func title(_ value: String) -> Modified {
        setValue(.title, .string(value))
    }

    /// The picture that stands for the page - a file in the app's
    /// Resources/Images, by the name MAUI gives it once built.
    /// MAUI: Page.IconImageSource.
    ///
    /// A tab's icon, in practice: it is what a TabbedPage draws above or beside
    /// the caption. A page that is not shown as an item of something else has
    /// nowhere to draw it, and platforms ignore it there.
    public func iconImageSource(_ value: ImageSource) -> Modified {
        setValue(.iconImageSource, value.propValue)
    }

    /// How the page covers the screen when it is PRESENTED over the window.
    /// MAUI: the `Page.ModalPresentationStyle` platform-specific.
    ///
    ///     var modalStack: ModalStack? {
    ///         ModalStack($sheets) { _ in
    ///             NavigationPage($sheetPath) {
    ///                 SettingsPage()
    ///             } destination: { … }
    ///             .modalPresentationStyle(.pageSheet)
    ///         }
    ///     }
    ///
    /// which is the usual shape of a sheet on iOS: a whole navigation stack
    /// presented as a card, with a bar and a Done button of its own.
    ///
    /// **iOS and Mac Catalyst only** - a written page says the same thing as
    /// `var modalPresentationStyle`, and both are ignored where a platform
    /// presents every modal page over the whole window.
    public func modalPresentationStyle(_ value: UIModalPresentationStyle) -> Modified {
        setValue(.modalPresentationStyle, value.propValue)
    }
}
