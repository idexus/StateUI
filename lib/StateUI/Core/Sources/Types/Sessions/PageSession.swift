// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A page's session: where the page stands in its life and what it says about
// itself, written as state and read into the page's node as it builds.
// Design: docs/design/types/sessions.md#told-not-derived

/// A content page as it runs: where it stands in its life, and the values it
/// is told about itself: its title, its picture, and what it asks of the stack
/// it is on.
///
///     @Environment private var page: PageSession
///
///     VStack { … }
///         .onCreated {
///             page.title = "Settings"
///         }
///
/// Every page offers its own to the view it shows and to everything in it, so
/// a view acts on the page it is in, and what the page is told stands until it
/// is told otherwise. Every optional property is nil until written, leaving
/// the native host to choose its default. What the page shows on its bar and
/// its menus are declared in its view instead - `.toolbar { }`,
/// `.titleView { }`, `.menuBar { }` - built with the state they follow. See `ApplicationSession` for what a session is.
///
/// An arrangement - a `NavigationStack`, a `TabView`, a `SplitView` - is a
/// page already and has none: it is told what it is by modifier, from
/// `PageElement`.
public final class PageSession {
    /// Where the page stands in its life right now. Starts `.created`.
    @State public internal(set) var phase: PagePhase = .created

    /// What the page is called.
    ///
    /// The navigation bar's text while this page is on top, and the caption of
    /// the tab holding it - the same meaning `.title(_:)` carries on an
    /// arrangement; see `PageElement`.
    @State public var title: String? = nil

    /// The picture that stands for the page.
    ///
    ///     page.icon = "house.png"
    ///
    /// A tab's icon, in practice - a `TabView` draws it above or beside the
    /// caption. A page that is not shown as an item of something else has
    /// nowhere to draw it, and platforms ignore it there.
    @State public var icon: ImageSource? = nil

    /// The space kept between the page's edge and its content.
    ///
    /// A page has no margin to go with it: nothing is outside a page.
    @State public var padding: Insets? = nil

    /// What is drawn behind the page.
    ///
    /// The PAGE's own - the bar above it is the arrangement's, and takes
    /// `barBackgroundColor` there.
    @State public var background: Color? = nil

    // What the page asks of the navigation stack it is on; the bar's colours
    // are the stack's own.

    /// Whether the navigation bar is shown while this page is on top.
    ///
    ///     page.showsNavigationBar = false    // a splash page
    @State public var showsNavigationBar: Bool? = nil

    /// Whether the way back is offered while this page is on top - false for a
    /// page the user must finish rather than leave.
    ///
    /// It controls the navigation stack's own back affordances. It is not a
    /// cross-platform lock against every system-level way of leaving a page.
    @State public var showsBackButton: Bool? = nil

    /// What the back button reads while the page ABOVE this one is on top.
    ///
    /// Written on the page the user would go back to, never on the one they
    /// are looking at. Hosts whose back affordance has no text ignore it.
    @State public var backButtonTitle: String? = nil

    /// A fresh session - what every content page is given as it is first
    /// built, and what a test or one branch provides as a fake with
    /// `.environment(...)`.
    public init() {}

    /// The page's properties for its node: each one written, and nothing for
    /// the rest, which leaves the native default standing.
    var props: [Prop: PropValue] {
        var props: [Prop: PropValue] = [:]

        props.describe(PageElementContract.title, title)
        props.describe(PageElementContract.icon, icon)
        props.describe(PageContract.padding, padding)
        props.describe(PageContract.background, background)
        props.describe(PageContract.showsNavigationBar, showsNavigationBar)
        props.describe(PageContract.showsBackButton, showsBackButton)
        props.describe(PageContract.backButtonTitle, backButtonTitle)
        return props
    }
}
