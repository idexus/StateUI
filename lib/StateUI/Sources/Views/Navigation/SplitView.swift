// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The split view: two pages, and whether the sidebar shows is a Bool the
// author holds, written back when the user shows or hides it.
// Design: docs/design/views/pages.md#split-view

/// A page holding two: a sidebar at the side and the page beside it.
///
///     enum Section: Hashable, CaseIterable { case today, archive }
///
///     struct MainWindow: Window {
///         @State private var section: Section = .today
///         @State private var menu = false
///
///         var page: any Page {
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
///     struct MenuPage: ContentView {
///         @Binding var section: Section
///         @Binding var menu: Bool
///         @Environment private var page: PageSession
///
///         var content: any View {
///             VStack {
///                 ForEach(Section.allCases, id: \.self) { which in
///                     Button("\(which)")
///                         .onClicked {
///                             section = which      // choose
///                             menu = false         // and close
///                         }
///                 }
///             }
///             .onCreated { page.title = "Sections" }   // required
///         }
///     }
///
/// A sidebar row is an ordinary view whose handler assigns state: choosing and
/// closing are two writes, and a sidebar that should stay open skips the
/// second. The platform's own ways to show or hide the sidebar - its button,
/// an edge swipe, a tap on the dimmed page - are written into the binding, and
/// a host with room for both pages may open with the sidebar showing. The
/// sidebar page must have a title.
public struct SplitView: Page, ModifiableElement, PageElement, PageArrangement {
    /// The node this page describes.
    public var node: Node

    /// The node, as every element answers it.
    public var body: Node { node }

    /// A sidebar beside `detail`, shown when `isSidebarVisible` says so.
    ///
    /// - Parameter isSidebarVisible: whether the sidebar shows, borrowed
    ///   two-way. The platform's own sidebar button, a swipe or a tap outside
    ///   it write here.
    /// - Parameter sidebar: the page at the side. It must have a title.
    /// - Parameter detail: the page beside it, which is the application.
    public init(
        _ isSidebarVisible: Binding<Bool>,
        sidebar: () -> any Page,
        detail: () -> any Page
    ) {
        node = Node(
            contract: SplitViewContract.self,
            children: [
                Self.identified(Node.page(sidebar()), as: Self.sidebarIdentity),
                Self.identified(Node.page(detail()), as: Self.detailIdentity),
            ])
        node.write(SplitViewContract.isSidebarVisible, isSidebarVisible.wrappedValue)

        // The user's ways in and out, once finished, written only when moved.
        node.addHandler(SplitViewContract.isSidebarVisibleChanged.token) {
            guard let visible = EventBuffer.current.value()?.bool,
                  visible != isSidebarVisible.wrappedValue else { return }

            isSidebarVisible.wrappedValue = visible
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
