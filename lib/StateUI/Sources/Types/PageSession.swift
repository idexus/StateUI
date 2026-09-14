// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A PAGE as it runs: where it stands in its life, and everything it says about
// itself - what it is called, its buttons, how it is presented. This
// library's own, the fourth session beside the application's, the scene's and
// the window's: what a page IS is written into it as state, usually from the
// `.onCreated` of its content, and read into the page's node every time the
// page is built.
//
//     struct FeedPage: ContentView {
//         @Environment private var page: PageSession
//         @State private var greeting = "Hello"
//
//         var content: any View {
//             Label(greeting)
//                 .onCreated {
//                     page.title = "Feed"
//                     page.toolbarItems = [
//                         ToolbarItem("Refresh").onClicked { greeting = try await load() }
//                     ]
//                 }
//                 .onChanged(page.phase) {
//                     if page.phase == .appearing { greeting = try await load() }
//                 }
//         }
//     }
//
// WHY STATE AND NOT A GETTER. A page's title is not worked out from the page's
// state on every build: it is what the page was TOLD, and it changes when
// something says so - which is exactly a `@State` a handler writes. So the page
// is built again when its session is written, by the rule every state follows,
// and is asked nothing on a build caused by anything else. And what
// `.onCreated` writes is in the message that BRINGS the page - see
// `Renderer.renderWire` - which is what a presented page's style and a bar's
// buttons need: the platform acts on the message that makes them.
//
// ONE PER PAGE, HELD BY ITS ELEMENT. A page is a value built again on every
// render, so the session lives on the element the page is: made when the page
// is first built, handed back on every build after, gone with it. See
// Core/ElementSession.swift.
//
// A VALUE written here is put on the page as the page is built, and a colour
// or a picture with a half for each theme is picked there - right in both,
// whenever it was written. A VIEW written here - the title view, a button - is
// built where it is shown: a composed view there reads its own state as it
// builds, and is built again when that moves.

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

    /// A MOVE has arrived at it - navigation and nothing else, where appearing
    /// also answers the page coming back for a reason that was never a move.
    case navigatedTo

    /// A move is about to leave it - it is still the page on screen, which
    /// makes this the moment to put away what the move must not carry.
    case navigatingFrom

    /// It has been covered or left - forward, back, or to another tab.
    case disappearing

    /// A move has left it; the destination is now on screen.
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
    ///     page.iconImageSource = "house.png"
    ///
    /// A tab's icon, in practice - a `TabbedView` draws it above or beside the
    /// caption. A page that is not shown as an item of something else has
    /// nowhere to draw it, and platforms ignore it there.
    @State public var iconImageSource: ImageSource? = nil

    /// The space kept between the page's edge and its content.
    ///
    /// A page has no margin to go with it: nothing is outside a page.
    @State public var padding: Thickness? = nil

    /// What is drawn behind the page.
    ///
    /// The PAGE's own - the bar above it is the arrangement's, and takes
    /// `barBackgroundColor` there.
    @State public var background: Color? = nil

    // What this page asks of the NAVIGATION STACK it is on. The colours of
    // the BAR belong to the NavigationStack rather than to a page on it - see
    // `barBackgroundColor` in Views/BarElement.swift.

    /// Whether the navigation bar is shown while this page is on top.
    ///
    ///     page.hasNavigationBar = false    // a splash page
    @State public var hasNavigationBar: Bool? = nil

    /// Whether the way back is offered while this page is on top - false for a
    /// page the reader must finish rather than leave.
    ///
    /// It controls the navigation stack's own back affordances. It is not a
    /// cross-platform lock against every system-level way of leaving a page.
    @State public var hasBackButton: Bool? = nil

    /// What the back button reads while the page ABOVE this one is on top.
    ///
    /// Written on the page the reader would go BACK TO, never on the one they
    /// are looking at. Hosts whose back affordance has no text ignore it.
    @State public var backButtonTitle: String? = nil

    /// A view on the bar, in place of the title.
    ///
    ///     page.titleView = SearchField($query)
    ///
    /// A view rather than a handler: whatever is written here is an ordinary
    /// part of the tree, built where the bar is - a composed view there reads
    /// the state it shows as it builds, and a binding handed to a control
    /// keeps it live.
    @State public var titleView: (any View)? = nil

    /// The actions in the page's navigation bar or native toolbar.
    ///
    ///     page.toolbarItems = [
    ///         ToolbarItem("Add").onClicked { items.append(Item()) },
    ///         ToolbarItem("Sort").order(.secondary),
    ///     ]
    ///
    /// What the bar offers is what was written: a button whose caption follows
    /// the page's state is written again when that state moves -
    /// `.onChanged(editing) { page.toolbarItems = … }`.
    @State public var toolbarItems: [ToolbarItem] = []

    /// The menus active while this page is showing on a host with a menu bar.
    ///
    ///     page.menuBarItems = [
    ///         MenuBarItem("File") {
    ///             MenuFlyoutItem("New").onClicked { documents.append(Document()) }
    ///         }
    ///     ]
    @State public var menuBarItems: [MenuBarItem] = []

    /// A fresh session - what every content page is given as it is first
    /// built, and what a test or one branch provides as a fake with
    /// `.environment(...)`.
    public init() {}

    /// The page's properties as the host reads them - every one that says
    /// something and nothing for the rest, which leaves the native default
    /// standing. Read as the page builds, so the page builds again when one is
    /// written.
    var props: [Prop: PropValue] {
        var props: [Prop: PropValue] = [:]

        props[.title] = title.map { .string($0) }
        props[.iconImageSource] = iconImageSource?.propValue
        props[.padding] = padding?.propValue
        props[.background] = background?.propValue
        props[.hasNavigationBar] = hasNavigationBar.map { .bool($0) }
        props[.hasBackButton] = hasBackButton.map { .bool($0) }
        props[.backButtonTitle] = backButtonTitle.map { .string($0) }
        return props
    }

    /// What hangs off the page besides its content: the title view, the
    /// toolbar items and the menu bar items, each as the node the host knows
    /// it by.
    var slots: [Node] {
        var slots: [Node] = []

        if let titleView = titleView {
            slots.append(Node(type: .titleView, children: [titleView.body]))
        }

        // Collections rather than one node each, for the reason a SwipeView's
        // items are: the host has a list to keep in step, and a list needs
        // somewhere of its own to be matched against.
        if !toolbarItems.isEmpty {
            slots.append(Node(type: .toolbarItems, children: toolbarItems.map { $0.body }))
        }

        if !menuBarItems.isEmpty {
            slots.append(Node(type: .menuBarItems, children: menuBarItems.map { $0.body }))
        }

        return slots
    }
}
