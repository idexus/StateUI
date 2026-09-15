// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The tabs, owned by Swift.
//
// A TabbedView holds several pages and draws a native selector to move between
// them. WHICH tabs there are is an array the author holds, of the author's own
// type; WHICH ONE is showing is a binding of that same type. So the two
// questions a tab bar can be asked have answers on this side, and the host is
// told the arrangement and the index in the same message it is told everything
// else in.
//
//     enum Tab: Hashable, CaseIterable { case home, browse, settings }
//
//     @State private var tab: Tab = .home
//
//     TabbedView(Tab.allCases) { tab in
//         switch tab {
//         case .home:     HomePage()
//         case .browse:   BrowsePage()
//         case .settings: SettingsPage()
//         }
//     }
//     .selection($tab)
//
// Switching tabs from code is `tab = .settings`. Switching them with a finger
// is the host reporting which page became current, and the binding being
// written to match - the same protocol a completed pop follows in
// Views/NavigationStack.swift, and the same one a split view's `isSidebarVisible`
// follows.
//
// The tabs are a COLLECTION rather than a builder of pages, and that is what
// makes the identity work: a tab is a value, so the page for it can be
// identified BY it, and rearranging the array moves a tab without rebuilding
// what is on it.

/// A page showing several pages, one at a time, with a bar to choose between
/// them.
///
/// A tabbed application can be nothing but this - the tabs, the page for one,
/// and the state saying which is showing:
///
///     enum Tab: Hashable, CaseIterable { case today, settings }
///
///     struct DiaryApp: Application {
///         var scene: any Scene { MainWindow() }
///     }
///
///     struct MainWindow: Window {
///         @State private var tab: Tab = .today
///
///         var page: any Page {
///             TabbedView(Tab.allCases) { tab in
///                 switch tab {
///                 case .today:    TodayPage()
///                 case .settings: SettingsPage(tab: $tab)
///                 }
///             }
///             .selection($tab)
///         }
///     }
///
///     struct TodayPage: ContentView {
///         @Environment private var page: PageSession
///
///         var content: any View {
///             Label("Nothing due.")
///                 .onCreated {
///                     page.title = "Today"                   // the caption
///                     page.icon = "today.png"     // and the icon
///                 }
///         }
///     }
///
/// **A tab's caption and icon come from its PAGE**, through `title` and
/// `icon`. A page the
/// library constructs - a `NavigationStack` inside a tab, which is the ordinary
/// shape of a tabbed application - is given them by modifier instead:
///
///     TabbedView(Tab.allCases) { tab in
///         switch tab {
///         case .home:
///             NavigationStack($homePath) {
///                 HomePage(path: $homePath)
///             } destination: { route in … }
///             .title("Home")
///
///         case .settings:
///             SettingsPage()
///         }
///     }
///     .selection($tab)
///
/// Each tab keeps a stack of its own that way, which is what a phone
/// application usually wants: leaving a tab and coming back finds it where it
/// was, because the path is `@State` and nothing threw it away.
///
/// **Moving between tabs from code** is assigning the binding - `tab =
/// .settings` - from anywhere that can reach it, which is why `SettingsPage`
/// above takes `$tab`. A tab the reader chooses arrives the other way: the host
/// reports which page became current and the binding is written, so the state
/// says what the screen says without a single line in the application.
///
/// **A tab may be added or taken away** by describing a different array - tabs
/// are data like anything else here. Removing the tab that is SHOWING is legal:
/// the platform picks another, reports it, and the binding follows it there.
///
/// **A tab must be a VALUE, and distinct values must READ differently**, since
/// a page's identity here is `String(describing:)` of its tab - the rule
/// `ForEach` states as "items must be DISTINCT within their parent", and the
/// one `NavigationStack` states for a route. A repeated tab is two tabs sharing
/// one page.
///
/// Position is NOT part of a tab's identity, which is the one place this
/// differs from a navigation stack. A stack may legitimately hold the same
/// route twice, so a page there is identified by its depth as well; a tab bar
/// holding one tab twice is a mistake, and identifying a tab by its value alone
/// is what lets the tabs be REORDERED without the pages being rebuilt.
///
/// **What is deliberately NOT here:**
///
/// - A builder of child pages. The tabs are a collection so that a tab can be
///   identified by its own value; a builder would hand back an anonymous list
///   whose only identity is position.
/// - A separate items source and item template. Passing an array and a
///   closure already is that data-driven form.
/// - The current page as a readable property. The bound selection answers it
///   on this side, before the host has drawn anything.
public struct TabbedView: Page, ModifiableElement, BarElement, PageElement, PageArrangement {
    /// The node this page describes.
    public var node: Node

    /// The node, as every element answers it.
    public var body: Node { node }

    /// The tabs, kept as they were given so `selection` can find the one it
    /// names and name back the one a finger chose.
    ///
    /// `AnyHashable` because a TabbedView is not generic: the author's own
    /// type is known to the initializer alone. The box is opened again in
    /// `selection`, whose binding says which type to expect.
    private let tabs: [AnyHashable]

    /// Tabs over `tabs`, one page each.
    ///
    /// WHICH one is showing is `.selection($tab)`, a modifier like every other
    /// choice in this library - `Picker`'s `selectedIndex` and `GalleryView`'s
    /// `position`. A tabbed page with no
    /// selection is a bar the reader can still use and nothing reports back
    /// from, which is what those three do without their binding too.
    ///
    /// - Parameter tabs: what the tab bar offers, in order - the author's own
    ///   type, each value distinct.
    /// - Parameter destination: the page for one tab.
    public init<Tabs: RandomAccessCollection>(
        _ tabs: Tabs,
        destination: (Tabs.Element) -> any Page
    ) where Tabs.Element: Hashable {
        let ordered = Array(tabs)
        self.tabs = ordered.map { AnyHashable($0) }

        node = Node(
            contract: TabbedViewContract.self,
            children: ordered.map { tab in
                Self.identified(Node.page(destination(tab)), as: String(describing: tab))
            })
    }

    /// Which tab is showing, borrowed two-way. A tab the reader chooses is
    /// written here.
    ///
    ///     @State private var tab: Tab = .home
    ///
    ///     TabbedView(Tab.allCases) { tab in
    ///         switch tab {
    ///         case .home:     HomePage()
    ///         case .settings: SettingsPage(tab: $tab)
    ///         }
    ///     }
    ///     .selection($tab)
    ///
    /// Moving between tabs from code is `tab = .settings`. A binding whose
    /// value names no tab in the array says nothing, which is not an error -
    /// see below.
    ///
    /// - Parameter binding: the tab that is showing, of the same type the tabs
    ///   are.
    public func selection<Tab: Hashable>(_ binding: Binding<Tab>) -> TabbedView {
        var copy = self
        let ordered = tabs

        // WHICH page is current, as its position among the children - the same
        // list the initializer described, so the two cannot mean different
        // things. An index is what an arranged list already gives an address
        // in.
        //
        // Absent when the selection names no tab at all, which is not an error:
        // the platform is showing SOMETHING, it reports which, and the binding
        // is written to match on the way back. That is how a selected tab being
        // REMOVED resolves itself with no rule of its own.
        if let index = ordered.firstIndex(of: AnyHashable(binding.wrappedValue)) {
            copy.node.write(TabbedViewContract.currentPage, index)
        }

        // The reader's own way between tabs. The payload is the index of the
        // page that is now current, which is this side's index because it is a
        // position in the list this side described.
        //
        // Written only when it MOVED: a host may report the selection reached
        // through either direction, and a binding written with
        // the value it already holds would be a render nobody asked for. The
        // host guards the same thing from its side; both are cheap and the
        // pair is what keeps a tab switch to exactly one render.
        copy.node.addHandler(TabbedViewContract.currentPageChanged.token) {
            guard let index = EventBuffer.current.value()?.int,
                  index >= 0, index < ordered.count,
                  // A binding of a type the tabs are not - the one mistake this
                  // erasure makes possible - names nothing rather than
                  // trapping, exactly as a value that is not among the tabs
                  // does above.
                  let tab = ordered[index].base as? Tab else { return }

            guard tab != binding.wrappedValue else { return }

            binding.wrappedValue = tab
        }

        return copy
    }

    // MARK: - Who a tab's page is

    /// A page node wearing the identity its tab gives it.
    ///
    /// The stack's rule, for the stack's reason: identity on an arrangement is
    /// what pairs a report with the page it is about, so it belongs to the
    /// mechanism rather than to the author - who cannot write it here anyway,
    /// an `.id()` written on the view staying on the view the page shows.
    private static func identified(_ node: Node, as identity: String) -> Node {
        var copy = node
        copy.id = identity
        return copy
    }
}
