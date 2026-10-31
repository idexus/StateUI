// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The tabs: which tabs there are is a collection the author holds, and which
// one shows is a state of the same type, written back when the user chooses.
// Design: docs/design/views/pages.md#tabs-report-an-index

/// Several pages shown one at a time, with a bar to choose between them - a
/// view that stands where a page stands.
///
///     enum Tab: Hashable, CaseIterable { case today, settings }
///
///     struct MainPage: View {
///         @State private var tab: Tab = .today
///
///         var body: some View {
///             TabView(Tab.allCases) { tab in
///                 switch tab {
///                 case .today:    TodayPage()
///                 case .settings: SettingsPage(tab: $tab)
///                 }
///             }
///             .selection($tab)
///         }
///     }
///
///     struct TodayPage: View {
///         var body: some View {
///             Text("Nothing due.")
///                 .title("Today")                    // the caption
///                 .icon("today.png")                 // and the icon
///         }
///     }
///
/// A tab's caption and icon are what its view says of its page, `.title` and
/// `.icon`. A `NavigationStack` inside a tab takes them the same way and keeps
/// its own path while the user is on another tab.
///
/// Moving between tabs from code is assigning the binding, `tab = .settings`;
/// a tab the user chooses is written back into it. Tabs are data: describing
/// another array adds or removes tabs, and when the showing tab is removed the
/// platform picks another and the binding follows.
///
/// Each tab must be a distinct value. A page is keyed by its tab alone, so tabs
/// can be reordered without their pages being rebuilt.
public struct TabView<Tab: Hashable>: ElementView, Arrangement, BarElement, AutomationElement {
    /// The node this page describes.
    public var node: Node

    /// The tabs offered, in order - what a selection's index is a place in.
    private var tabs: [Tab] = []

    /// Tabs over `tabs`, one page each, the platform choosing which shows
    /// until the user does.
    ///
    /// - Parameters:
    ///   - tabs: what the tab bar offers, in order - the author's own type,
    ///     each value distinct.
    ///   - destination: the page for one tab.
    public init<Tabs: RandomAccessCollection, Destination: View>(
        _ tabs: Tabs,
        @ViewBuilder destination: (Tab) -> Destination
    ) where Tabs.Element == Tab {
        self.tabs = Array(tabs)
        node = Node(
            contract: TabViewContract.self,
            children: tabs.map { tab in
                Self.identified(Node.page(destination(tab)), as: tab)
            })
    }

    /// The tab that is showing, both ways: the tab view reads the state as it is described, and the tab the user
    /// chooses lands on it. Without it the platform chooses which shows until the user does.
    ///
    ///     TabView(Tab.allCases) { tab in … }
    ///         .selection($tab)
    public func selection(_ state: Binding<Tab>) -> Self {
        let ordered = tabs
        return modified { node in
            // The current page as its index among the children, and none where the state names no tab.
            // Design: docs/design/views/pages.md#tabs-report-an-index
            node.readsWhenDescribed { node in
                if let index = ordered.firstIndex(of: state.wrappedValue) {
                    node.write(TabViewContract.selectedTab, index)
                }
            }

            // The user's choice, as that index, written only when it moved.
            node.addHandler(TabViewContract.selectedTabChanged.token) {
                guard let index = EventBuffer.current.value()?.int, ordered.indices.contains(index),
                      ordered[index] != state.wrappedValue
                else { return }

                state.wrappedValue = ordered[index]
            }
        }
    }

    /// A page node wearing the key its tab gives it.
    private static func identified(_ node: Node, as tab: some Hashable) -> Node {
        var copy = node
        copy.identify(tab)
        return copy
    }
}
