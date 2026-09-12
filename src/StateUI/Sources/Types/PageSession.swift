// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A PAGE as it runs: where it stands in its life, and everything it says about
// itself - what it is called, its buttons, how it is presented. This
// library's own, the fourth session beside the application's, the scene's and
// the window's: what a page IS is written into it as state, usually from the
// `.onCreated` of its content, and read into the page's node every time the
// page is built.
//
//     struct FeedPage: ContentPage {
//         @Environment private var page: PageSession
//         @State private var items: [Item] = []
//
//         var content: any View {
//             LazyList(items) { … }
//                 .onCreated {
//                     page.title = "Feed"
//                     page.toolbarItems = [
//                         ToolbarItem("Refresh").onClicked { items = try await load() }
//                     ]
//                 }
//                 .onChanged(page.phase) {
//                     if page.phase == .appearing { items = try await load() }
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

/// Where a page stands in its life - the last of MAUI's five page events to
/// arrive. This library's own: MAUI has the events and no such enum.
///
///     .onChanged(page.phase) {
///         if page.phase == .appearing { try await refresh() }
///     }
///
/// It moves as the platform reports, which is not always in one order: a page
/// arriving says `appearing` then `navigatedTo`, one being left
/// `navigatingFrom`, `disappearing`, `navigatedFrom` - and a tab switched to
/// says `appearing` alone, a tab being no move. A report of the phase the page
/// is already in changes nothing.
public enum PagePhase: Sendable {
    /// Described, and not yet reported on screen - where every page starts.
    case created

    /// It is about to be shown - on every arrival, not only the first: coming
    /// back from a pushed page says it again. MAUI: Page.Appearing.
    case appearing

    /// A MOVE has arrived at it - navigation and nothing else, where appearing
    /// also answers the page coming back for a reason that was never a move.
    /// MAUI: Page.NavigatedTo.
    case navigatedTo

    /// A move is about to leave it - it is still the page on screen, which
    /// makes this the moment to put away what the move must not carry.
    /// MAUI: Page.NavigatingFrom.
    case navigatingFrom

    /// It has been covered or left - forward, back, or to another tab.
    /// MAUI: Page.Disappearing.
    case disappearing

    /// A move HAS left it - by now the destination is on screen.
    /// MAUI: Page.NavigatedFrom.
    case navigatedFrom
}

/// A content page as it runs: where it stands in its life, and everything it
/// says about itself - its title, its buttons, how it is presented, what it
/// asks of the stack it is on. This library's own - what MAUI keeps on its
/// `Page` object, as state a view reads and writes.
///
///     @Environment private var page: PageSession
///
///     VStack { … }
///         .onCreated {
///             page.title = "Settings"
///             page.modalPresentationStyle = .pageSheet
///         }
///
/// Every content page offers its own to itself and to everything in it, so a
/// view acts on the page it is in, and what the page is told stands until it
/// is told otherwise. Every property is nil until written, which leaves MAUI's
/// own default standing. See `ApplicationSession` for what a session is.
///
/// A page the library CONSTRUCTS - a `NavigationPage`, a `TabbedPage`, a
/// `FlyoutPage` - has none: it is a value, told what it is by modifier, from
/// `PageElement`.
public final class PageSession {
    /// Where the page stands in its life right now. Starts `.created`.
    @State public internal(set) var phase: PagePhase = .created

    /// What the page is called. MAUI: Page.Title.
    ///
    /// The navigation bar's text while this page is on top, and the caption of
    /// the tab holding it - the same meaning `.title(_:)` carries on a page the
    /// library constructs; see `PageElement`.
    @State public var title: String? = nil

    /// The picture that stands for the page. MAUI: Page.IconImageSource.
    ///
    ///     page.iconImageSource = "house.png"
    ///
    /// A tab's icon, in practice - a `TabbedPage` draws it above or beside the
    /// caption. A page that is not shown as an item of something else has
    /// nowhere to draw it, and platforms ignore it there.
    @State public var iconImageSource: ImageSource? = nil

    /// The space kept between the page's edge and its content.
    /// MAUI: Page.Padding.
    ///
    /// A page has no margin to go with it: nothing is outside a page.
    @State public var padding: Thickness? = nil

    /// What is drawn behind the page. MAUI: VisualElement.BackgroundColor.
    ///
    /// The PAGE's own - the bar above it is the arrangement's, and takes
    /// `barBackgroundColor` there.
    @State public var backgroundColor: Color? = nil

    /// A picture behind the whole page, under its content.
    /// MAUI: Page.BackgroundImageSource.
    ///
    /// The trap is that this is BEHIND everything and takes no aspect: it is a
    /// backdrop, where an `Image` in the content is a view that can be sized
    /// and placed.
    @State public var backgroundImageSource: ImageSource? = nil

    /// Whether a tap outside a focused input closes the keyboard.
    /// MAUI: ContentPage.HideSoftInputOnTapped.
    ///
    /// The platform's own answer to a keyboard with no way out, and the reason
    /// this library adds no tap-catching view of its own: MAUI recognizes the
    /// tap ALONGSIDE whatever else is listening, so a scroll, a button and a
    /// gesture on the page all go on working - a view laid over the content to
    /// catch touches could not promise that.
    ///
    /// It takes a TAP on the page to fire, and unfocuses whichever view the
    /// page has focused. A keyboard that has to be closed by something else -
    /// a Done button over a form of six fields - is `SoftInput.hide()`, which
    /// asks the page who holds the focus; see Core/Focus.swift.
    @State public var hideSoftInputOnTapped: Bool? = nil

    /// Whether this page keeps its content out of the bars - the status bar,
    /// the notch, the home indicator, and on Mac Catalyst the window's title
    /// bar. MAUI: the `Page.UseSafeArea` iOS platform-specific.
    ///
    ///     page.useSafeArea = false    // a header that runs to the top
    ///
    /// True is the platform's own answer and what a page gets by saying
    /// nothing. FALSE is for a page whose top is a picture rather than text -
    /// a flyout's banner, a hero image - which has to reach the edge or the
    /// page's own colour shows above it in a strip.
    ///
    /// **iOS and Mac Catalyst only**, being a UIKit platform-specific; Android
    /// and Windows ignore it. It is the PAGE's inset, which is what makes it
    /// different from `.safeAreaEdges()` on a layout: measured on Catalyst, a
    /// layout saying `.none` still began below the title bar, because the page
    /// under it had already taken the inset out of the room it was given.
    @State public var useSafeArea: Bool? = nil

    /// How the page covers the screen when it is PRESENTED over the window -
    /// a sheet, a card, the whole screen.
    /// MAUI: the `Page.ModalPresentationStyle` platform-specific.
    ///
    ///     page.modalPresentationStyle = .pageSheet
    ///
    /// **iOS and Mac Catalyst only.** UIKit is the only platform with a choice
    /// here; Android and Windows present every modal page over the whole
    /// window. Written in the page's `.onCreated`, it is in the message that
    /// presents the page, which is when UIKit reads it. See
    /// `WindowSession.modalStack`, which is what presents one, and
    /// `UIModalPresentationStyle` for what each style draws.
    ///
    /// It says nothing about a page reached any other way: a page pushed onto a
    /// navigation stack or shown as a tab is not presented, and ignores it.
    @State public var modalPresentationStyle: UIModalPresentationStyle? = nil

    // What this page asks of the NAVIGATION STACK it is on. Attached
    // properties, so each carries the class that declares it -
    // `NavigationPage.HasNavigationBar` is `navigationPageHasNavigationBar`.
    // The colours of the BAR belong to the NavigationPage rather than to a
    // page on it - see `barBackgroundColor` in Views/BarElement.swift.

    /// Whether the navigation bar is shown while this page is on top.
    /// MAUI: NavigationPage.HasNavigationBar.
    ///
    ///     page.navigationPageHasNavigationBar = false    // a splash page
    @State public var navigationPageHasNavigationBar: Bool? = nil

    /// Whether the way back is offered while this page is on top - false for a
    /// page the reader must finish rather than leave.
    /// MAUI: NavigationPage.HasBackButton.
    ///
    /// It hides the BUTTON, and iOS's swipe-back with it. Android's system
    /// back is the platform's and goes on working, so a page that must not be
    /// left cannot be built out of this alone.
    @State public var navigationPageHasBackButton: Bool? = nil

    /// What the back button reads while the page ABOVE this one is on top.
    /// MAUI: NavigationPage.BackButtonTitle.
    ///
    /// Written on the page the reader would go BACK TO, never on the one they
    /// are looking at: iOS draws the title of the page underneath on the back
    /// button, and this is how that page says something shorter. Android and
    /// Windows draw an arrow with nowhere to put words, and ignore it.
    @State public var navigationPageBackButtonTitle: String? = nil

    /// A small picture beside the title on the bar.
    /// MAUI: NavigationPage.TitleIconImageSource.
    @State public var navigationPageTitleIconImageSource: ImageSource? = nil

    /// The colour of the back arrow on the bar.
    /// MAUI: NavigationPage.IconColor - `barTextColor` on the NavigationPage
    /// paints the title and the arrow together, and this overrides the arrow.
    @State public var navigationPageIconColor: Color? = nil

    /// A view on the bar, in place of the title.
    /// MAUI: NavigationPage.TitleView.
    ///
    ///     page.navigationPageTitleView = SearchBar($query)
    ///
    /// A view rather than a handler: whatever is written here is an ordinary
    /// part of the tree, built where the bar is - a composed view there reads
    /// the state it shows as it builds, and a binding handed to a control
    /// keeps it live.
    @State public var navigationPageTitleView: (any View)? = nil

    /// The buttons in the page's navigation bar. MAUI: Page.ToolbarItems.
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

    /// The menus on the desktop menu bar while this page is showing.
    /// MAUI: Page.MenuBarItems - which a phone has nowhere to put and shows
    /// none of, in MAUI as here.
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
    /// something, and nothing for the rest, which leaves MAUI's own default
    /// standing. Read as the page builds, so the page is what builds again
    /// when one is written.
    var props: [Prop: PropValue] {
        var props: [Prop: PropValue] = [:]

        props[.title] = title.map { .string($0) }
        props[.iconImageSource] = iconImageSource?.propValue
        props[.padding] = padding?.propValue
        props[.backgroundColor] = backgroundColor?.propValue
        props[.hideSoftInputOnTapped] = hideSoftInputOnTapped.map { .bool($0) }
        props[.backgroundImageSource] = backgroundImageSource?.propValue
        props[.useSafeArea] = useSafeArea.map { .bool($0) }
        props[.modalPresentationStyle] = modalPresentationStyle?.propValue

        props[.navigationPageHasNavigationBar] = navigationPageHasNavigationBar.map { .bool($0) }
        props[.navigationPageHasBackButton] = navigationPageHasBackButton.map { .bool($0) }
        props[.navigationPageBackButtonTitle] = navigationPageBackButtonTitle.map { .string($0) }
        props[.navigationPageTitleIconImageSource] = navigationPageTitleIconImageSource?.propValue
        props[.navigationPageIconColor] = navigationPageIconColor?.propValue

        return props
    }

    /// What hangs off the page besides its content: the title view, the
    /// toolbar items and the menu bar items, each as the node the host knows
    /// it by.
    var slots: [Node] {
        var slots: [Node] = []

        if let titleView = navigationPageTitleView {
            slots.append(Node(type: .navigationPageTitleView, children: [titleView.body]))
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
