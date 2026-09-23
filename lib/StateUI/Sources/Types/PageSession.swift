// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A page's session: where the page stands in its life and what it says about
// itself, written as state and read into the page's node as it builds.
// Design: docs/design/types/sessions.md#told-not-derived

/// Where a page stands in its native lifecycle.
///
///     .onChanged(page.phase) {
///         if page.phase == .appearing { try await refresh() }
///     }
///
/// It moves as the platform reports, which is not always in one order: a page
/// arriving says `appearing` then `navigatedTo`, while one being left says
/// `navigatingFrom`, `disappearing`, then `navigatedFrom`. A tab becoming
/// visible can say `appearing` without navigation. Reporting the current phase
/// again changes nothing.
public enum PagePhase: Sendable {
    /// Described, and not yet reported on screen - where every page starts.
    case created

    /// It is about to be shown - on every arrival, not only the first: coming
    /// back from a pushed page says it again.
    case appearing

    /// Navigation has arrived at it. Only navigation says this, while
    /// `appearing` also answers a page shown again for any other reason.
    case navigatedTo

    /// Navigation is about to leave it. It is still the page on screen: the
    /// moment to put away what the navigation must not carry.
    case navigatingFrom

    /// It has been covered or left - forward, back, or to another tab.
    case disappearing

    /// Navigation has left it; the destination is on screen.
    case navigatedFrom
}

/// A content page as it runs: where it stands in its life, and everything it
/// says about itself: its title, its actions, and what it asks of the stack it
/// is on.
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
/// the native host to choose its default. See `ApplicationSession` for what a
/// session is.
///
/// An arrangement - a `NavigationStack`, a `TabbedView`, a `SplitView` - is a
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
    /// A tab's icon, in practice - a `TabbedView` draws it above or beside the
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
    ///     page.hasNavigationBar = false    // a splash page
    @State public var hasNavigationBar: Bool? = nil

    /// Whether the way back is offered while this page is on top - false for a
    /// page the user must finish rather than leave.
    ///
    /// It controls the navigation stack's own back affordances. It is not a
    /// cross-platform lock against every system-level way of leaving a page.
    @State public var hasBackButton: Bool? = nil

    /// What the back button reads while the page ABOVE this one is on top.
    ///
    /// Written on the page the user would go back to, never on the one they
    /// are looking at. Hosts whose back affordance has no text ignore it.
    @State public var backButtonTitle: String? = nil

    /// A view on the bar, in place of the title.
    ///
    ///     page.titleView = SearchField($query)
    ///
    /// An ordinary part of the tree, built where the bar is: a composed view
    /// there reads its own state, and a binding handed to a control keeps it
    /// live.
    @State public var titleView: (any View)? = nil

    /// The actions in the page's navigation bar or native toolbar.
    ///
    ///     page.toolbarItems = [
    ///         ToolbarItem("Add").onClicked { items.append(Item()) },
    ///         ToolbarItem("Sort").placement(.overflow),
    ///     ]
    ///
    /// What the bar offers is what was written: a button whose caption follows
    /// the page's state is written again when that state moves -
    /// `.onChanged(editing) { page.toolbarItems = … }`.
    @State public var toolbarItems: [ToolbarItem] = []

    /// The menus active while this page is showing on a host with a menu bar.
    ///
    ///     page.menuBar = [
    ///         Menu("File") {
    ///             MenuItem("New").onClicked { documents.append(Document()) }
    ///         }
    ///     ]
    @State public var menuBar: [Menu] = []

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
        props.describe(PageContract.hasNavigationBar, hasNavigationBar)
        props.describe(PageContract.hasBackButton, hasBackButton)
        props.describe(PageContract.backButtonTitle, backButtonTitle)
        return props
    }

    /// What hangs off the page besides its content: the title view, the
    /// toolbar items and the menus, each as the node the host knows it by.
    var slots: [Node] {
        var slots: [Node] = []

        if let titleView = titleView {
            slots.append(Node(contract: TitleViewContract.self, children: [titleView.body]))
        }

        // One node per collection, a parent the host's list is matched against.
        // Design: docs/design/types/sessions.md#collections-hang-as-one-node
        if !toolbarItems.isEmpty {
            slots.append(Node(contract: ToolbarItemsContract.self, children: toolbarItems.map { $0.body }))
        }

        if !menuBar.isEmpty {
            slots.append(Node(contract: MenuBarContract.self, children: menuBar.map { $0.body }))
        }

        return slots
    }
}
