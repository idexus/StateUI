// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The split view, owned by Swift.
//
// A SplitView is two pages: a sidebar beside the page the reader is actually
// looking at. Whether the sidebar shows is a `Bool` the AUTHOR holds, borrowed
// two-way - so showing it from code is `isSidebarVisible = true`, and a reader
// who hides it writes `false` back through the same binding.
//
//     @State private var menu = false
//
//     SplitView($menu) {
//         MenuPage(section: $section, menu: $menu)  // the sidebar
//     } detail: {
//         NavigationStack($path) { … } destination: { … }
//     }
//
// The SIDEBAR IS AN ORDINARY PAGE: the rows are whatever views the author
// writes, a row is a Button whose handler assigns state, and nothing about it -
// no item type, no template, no selection of its own - is the library's
// business.

/// A page holding two: a sidebar at the side and the page beside it.
///
/// A whole application, and this is all of it:
///
///     enum Section: Hashable, CaseIterable { case today, archive }
///
///     struct DiaryApp: Application {
///         var scene: any Scene { MainWindow() }
///     }
///
///     struct MainWindow: Window {
///         @State private var section: Section = .today
///         @State private var menu = false
///
///         var page: any View {
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
///             .onCreated { page.title = "Sections" }   // REQUIRED - see below
///         }
///     }
///
/// Note what a row is: **a Button whose handler assigns state**. Choosing and
/// closing are two ordinary writes, in the order the author wants them, and a
/// sidebar that should stay open simply does not write the second.
///
/// **What the reader can do**, and it arrives as a write to the binding: the
/// platform's own sidebar button, a swipe from the edge, a tap on the shaded
/// detail page - whichever the platform offers. Each ends in
/// `isSidebarVisible` saying what is true, so the state and the screen cannot
/// disagree.
///
/// **A wide screen may open with both pages showing.** A host with room for
/// both may show the sidebar when the window first appears; the binding then
/// settles on `true`, and from there the reader and the application decide.
///
/// **What is deliberately NOT here:**
///
/// - A sidebar ITEM type, a sidebar template, a sidebar header and footer. The
///   sidebar is a page; a header is a view at the top of it.
/// - A way to turn the sidebar off for good while keeping the page it is on. A
///   `SplitView` is made of its two pages - an application with nothing to put
///   in a sidebar does not use one.
/// - A shared overlay/split policy or gesture switch. Those are capabilities
///   of a particular native container. The host adapts its own presentation;
///   StateUI owns the two pages and whether the sidebar shows.
public struct SplitView: View, PageElement, PageArrangement {
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
        sidebar: () -> any View,
        detail: () -> any View
    ) {
        node = Node(
            type: .splitView,
            props: [.isSidebarVisible: .bool(isSidebarVisible.wrappedValue)],
            children: [
                Self.identified(Node.page(sidebar()), as: Self.sidebarIdentity),
                Self.identified(Node.page(detail()), as: Self.detailIdentity),
            ])

        // The reader's own ways in and out - the platform's sidebar button,
        // the edge swipe, the tap on the dimmed detail page - all end here,
        // and only once the gesture has FINISHED: an interactive swipe let go
        // halfway reports whatever it settled on, which is what the screen
        // shows.
        //
        // Written only when it MOVED, the rule every binding in this library
        // follows: a host can report either direction, and a binding written
        // with the value it already holds would be a render nobody asked for.
        node.addHandler(.isSidebarVisibleChanged) {
            guard let visible = EventBuffer.current.value()?.bool,
                  visible != isSidebarVisible.wrappedValue else { return }

            isSidebarVisible.wrappedValue = visible
        }
    }

    // MARK: - Who the two pages are

    /// What the sidebar is called among its siblings.
    private static let sidebarIdentity = "sidebar"

    /// And what the page beside it is called.
    private static let detailIdentity = "detail"

    /// A page node wearing the identity the arrangement gives it.
    ///
    /// Identity here is what pairs a page with its half of the layout, so it
    /// belongs to the mechanism rather than to the author - the same rule a
    /// `NavigationStack` follows for the pages in its stack.
    private static func identified(_ node: Node, as identity: String) -> Node {
        var copy = node
        copy.id = identity
        return copy
    }
}
