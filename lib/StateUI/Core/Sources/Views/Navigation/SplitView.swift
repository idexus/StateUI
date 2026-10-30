// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The split view: two pages, and whether the sidebar shows is a Bool the
// author holds, written back when the user shows or hides it.
// Design: docs/design/views/pages.md#split-view

/// Two pages: a sidebar at the side and the page beside it - a view that stands
/// where a page stands.
///
///     enum Section: Hashable, CaseIterable { case today, archive }
///
///     struct MainPage: View {
///         @State private var section: Section = .today
///         @State private var menu = false
///
///         var body: some View {
///             SplitView($menu) {
///                 MenuPage(section: $section, menu: $menu)
///             } detail: {
///                 switch section {
///                 case .today:   TodayPage(menu: $menu)
///                 case .archive: ArchivePage(menu: $menu)
///                 }
///             }
///         }
///     }
///
///     struct MenuPage: View {
///         @Binding var section: Section
///         @Binding var menu: Bool
///
///         var body: some View {
///             VStack {
///                 ForEach(Section.allCases, id: \.self) { which in
///                     Button("\(which)")
///                         .onClicked {
///                             section = which      // choose
///                             menu = false         // and close
///                         }
///                 }
///             }
///             .title("Sections")   // names the sidebar's bar
///         }
///     }
///
/// A sidebar row is an ordinary view whose handler assigns state: choosing and
/// closing are two writes, and a sidebar that should stay open skips the
/// second - one beside the page, which `sidebarOverlays(_:)` tells apart from
/// one over it. The platform's own ways to show or hide the sidebar - its button,
/// an edge swipe, a tap on the dimmed page - are written into the binding, and
/// a host with room for both pages may open with the sidebar showing. The
/// sidebar page's title names the sidebar's bar; a sidebar page with none
/// shows the application's name there.
public struct SplitView: ElementView, Arrangement, BarElement, AutomationElement {
    /// The node this page describes.
    public var node: Node

    /// A sidebar beside `detail`, shown when `showsSidebar` says so.
    ///
    /// - Parameter showsSidebar: whether the sidebar shows, borrowed
    ///   two-way. The platform's own sidebar button, a swipe or a tap outside
    ///   it write here.
    /// - Parameter sidebar: the page at the side; its title names the
    ///   sidebar's bar, the application's name where it says none.
    /// - Parameter detail: the page beside it, which is the application.
    public init<Sidebar: View, Detail: View>(
        _ showsSidebar: some TwoWay<Bool>,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        node = Node(
            contract: SplitViewContract.self,
            children: [
                Self.identified(Node.page(sidebar()), as: Self.sidebarIdentity),
                Self.identified(Node.page(detail()), as: Self.detailIdentity),
            ])
        node.write(SplitViewContract.showsSidebar, showsSidebar.wrappedValue)

        // The user's ways in and out, once finished, written only when moved.
        node.addHandler(SplitViewContract.showsSidebarChanged.token) {
            guard let visible = EventBuffer.current.value()?.bool,
                  visible != showsSidebar.wrappedValue else { return }

            showsSidebar.wrappedValue = visible
        }
    }

    /// The sidebar's key among its siblings.
    private static let sidebarIdentity = "sidebar"

    /// And the key of the page beside it.
    private static let detailIdentity = "detail"

    /// A page node wearing the key the arrangement gives it.
    private static func identified(_ node: Node, as identity: String) -> Node {
        var copy = node
        copy.id = identity
        return copy
    }
}

extension SplitView {
    /// Whether the split view's bar offers the toggle that shows and hides
    /// the sidebar - offered unless this says not. A value from a state keeps
    /// it to some pages, as to the root of the detail's stack:
    ///
    ///     SplitView($menu) { MenuPage() } detail: {
    ///         NavigationStack($path) { InboxPage() } destination: { MailPage(id: $0) }
    ///     }
    ///     .showsSidebarToggle(path.isEmpty)
    ///
    /// With no toggle the sidebar shows and hides by the binding, and by an
    /// edge swipe where the platform has one.
    public func showsSidebarToggle(_ value: Bool) -> Modified {
        setValue(SplitViewContract.showsSidebarToggle, value)
    }

    /// `showsSidebarToggle` from a state, `$x`: the host shows or hides the
    /// toggle as the state changes, and no view is rebuilt for it.
    public func showsSidebarToggle(_ state: Binding<Bool>) -> Modified {
        twin(SplitViewContract.showsSidebarToggle, by: state)
    }

    /// What the sidebar stands on while it stands beside the detail.
    ///
    ///     SplitView($showsMenu) { MenuPage() } detail: { NotesPage() }
    ///         .sidebarBackground(.blur(.thin))
    ///         .sidebarOverlayBackground(.blur(.thick))
    ///
    /// Leave it unwritten for the platform's own: on the desktop the window
    /// shows through a sidebar.
    public func sidebarBackground(_ value: Material) -> Modified {
        setValue(SplitViewContract.sidebarBackground, value)
    }

    /// What the sidebar stands on while it slides over the detail - a phone's
    /// drawer, the sidebar of a narrow window. Leave it unwritten for the
    /// window's background laid over the platform's own surface there, which
    /// never lets the detail through.
    public func sidebarOverlayBackground(_ value: Material) -> Modified {
        setValue(SplitViewContract.sidebarOverlayBackground, value)
    }

    /// Whether the sidebar lies over the detail - a phone's drawer, the
    /// sidebar of a narrow window - written into a state by the host as the
    /// platform places it for the room; false while it stands beside the
    /// detail. A sidebar row reads it to close the sidebar over the page once
    /// the user has chosen, and to leave one beside the page open.
    ///
    ///     @State private var menu = false
    ///     @State private var menuOverlays = false
    ///
    ///     SplitView($menu) { MenuPage(menu: $menu, overlays: $menuOverlays) } detail: { NotesPage() }
    ///         .sidebarOverlays($menuOverlays)
    ///
    ///     // in a sidebar row's handler
    ///     section = which
    ///     if overlays { menu = false }
    ///
    /// - Parameter state: the state the sidebar's place is written into.
    /// - Returns: the split view, reporting its sidebar's place there.
    public func sidebarOverlays(_ state: Binding<Bool>) -> Modified {
        plain(SplitViewContract.sidebarOverlays.token, by: state, mode: .in)
    }

    /// `sidebarBackground` from a state, `$x`: the host shows each new material
    /// as it stands, and no view is rebuilt for it.
    public func sidebarBackground(_ state: Binding<Material>) -> Modified {
        twin(SplitViewContract.sidebarBackground, by: state)
    }

    /// `sidebarOverlayBackground` from a state, `$x`: the host shows each new material
    /// as it stands, and no view is rebuilt for it.
    public func sidebarOverlayBackground(_ state: Binding<Material>) -> Modified {
        twin(SplitViewContract.sidebarOverlayBackground, by: state)
    }
}
