// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The tabs: which tabs there are is a collection the author holds, and which
// one shows is a binding of the same type, written back when the user chooses.
// Design: docs/design/views/pages.md#tabs-report-an-index

/// A page showing several pages, one at a time, with a bar to choose between
/// them.
///
///     enum Tab: Hashable, CaseIterable { case today, settings }
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
///                     page.title = "Today"           // the caption
///                     page.icon = "today.png"        // and the icon
///                 }
///         }
///     }
///
/// A tab's caption and icon come from its page, through `title` and `icon`. A
/// `NavigationStack` inside a tab is given them by modifier, `.title("Home")`,
/// and keeps its own path while the user is on another tab.
///
/// Moving between tabs from code is assigning the binding, `tab = .settings`;
/// a tab the user chooses is written back into it. Tabs are data: describing
/// another array adds or removes tabs, and when the showing tab is removed the
/// platform picks another and the binding follows.
///
/// Each tab must be a distinct value whose values describe differently
/// (`String(describing:)`). A page is keyed by its tab alone, so tabs can be
/// reordered without their pages being rebuilt.
public struct TabbedView: Page, ModifiableElement, BarElement, PageElement, PageArrangement {
    /// The node this page describes.
    public var node: Node

    /// The node, as every element answers it.
    public var body: Node { node }

    /// The tabs as given, so `selection` can find the one it names and name
    /// back the one the user chose.
    private let tabs: [AnyHashable]

    /// Tabs over `tabs`, one page each; `.selection($tab)` says which shows.
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

    /// Which tab is showing, borrowed two-way: `tab = .settings` moves to a
    /// tab, and a tab the user chooses is written here.
    ///
    ///     TabbedView(Tab.allCases) { tab in … }
    ///         .selection($tab)
    ///
    /// A value that names no tab selects nothing, and the binding follows the
    /// tab the platform then shows.
    ///
    /// - Parameter binding: the tab that is showing, of the tabs' own type.
    public func selection<Tab: Hashable>(_ binding: Binding<Tab>) -> TabbedView {
        var copy = self
        let ordered = tabs

        // The current page as its index among the children, and none where the
        // binding names no tab: the platform then reports what it shows.
        // Design: docs/design/views/pages.md#tabs-report-an-index
        if let index = ordered.firstIndex(of: AnyHashable(binding.wrappedValue)) {
            copy.node.write(TabbedViewContract.currentPage, index)
        }

        // The user's choice, as that index, written only when it moved.
        copy.node.addHandler(TabbedViewContract.currentPageChanged.token) {
            guard let index = EventBuffer.current.value()?.int,
                  index >= 0, index < ordered.count,
                  // A binding of another type than the tabs names nothing.
                  let tab = ordered[index].base as? Tab else { return }

            guard tab != binding.wrappedValue else { return }

            binding.wrappedValue = tab
        }

        return copy
    }

    /// A page node wearing the key its tab gives it.
    private static func identified(_ node: Node, as identity: String) -> Node {
        var copy = node
        copy.id = identity
        return copy
    }
}
