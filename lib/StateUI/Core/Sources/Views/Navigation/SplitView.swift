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
///             .title("Sections")   // required
///         }
///     }
///
/// A sidebar row is an ordinary view whose handler assigns state: choosing and
/// closing are two writes, and a sidebar that should stay open skips the
/// second. The platform's own ways to show or hide the sidebar - its button,
/// an edge swipe, a tap on the dimmed page - are written into the binding, and
/// a host with room for both pages may open with the sidebar showing. The
/// sidebar page must have a title.
public struct SplitView: ElementView, Arrangement, BarElement {
    /// The node this page describes.
    public var node: Node

    /// A sidebar beside `detail`, shown when `showsSidebar` says so.
    ///
    /// - Parameter showsSidebar: whether the sidebar shows, borrowed
    ///   two-way. The platform's own sidebar button, a swipe or a tap outside
    ///   it write here.
    /// - Parameter sidebar: the page at the side. It must have a title.
    /// - Parameter detail: the page beside it, which is the application.
    public init<Sidebar: View, Detail: View>(
        _ showsSidebar: Binding<Bool>,
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
    /// What the sidebar stands on while it stands beside the detail.
    ///
    ///     SplitView($showsMenu) { MenuPage() } detail: { NotesPage() }
    ///         .sidebarBackground(.blur(.thin))
    ///         .flyoutBackground(.blur(.thick))
    ///
    /// Leave it unwritten for the platform's own: on the desktop the window
    /// shows through a sidebar.
    public func sidebarBackground(_ value: Material) -> Modified {
        setValue(SplitViewContract.sidebarBackground, value)
    }

    /// What the sidebar stands on while it slides over the detail - a phone's
    /// drawer, the sidebar of a narrow window. Leave it unwritten for the
    /// platform's own surface there, which never lets the detail through.
    public func flyoutBackground(_ value: Material) -> Modified {
        setValue(SplitViewContract.flyoutBackground, value)
    }

    /// `sidebarBackground` from a state, `$x`: the host shows each new material
    /// as it stands, and no view is rebuilt for it.
    public func sidebarBackground(_ state: Binding<Material>) -> Modified {
        plain(SplitViewContract.sidebarBackground, by: state)
    }

    /// `flyoutBackground` from a state, `$x`: the host shows each new material
    /// as it stands, and no view is rebuilt for it.
    public func flyoutBackground(_ state: Binding<Material>) -> Modified {
        plain(SplitViewContract.flyoutBackground, by: state)
    }
}
