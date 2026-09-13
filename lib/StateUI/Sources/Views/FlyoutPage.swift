// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The flyout, owned by Swift.
//
// A FlyoutPage is two pages: one that appears at the side and one the
// reader is actually looking at. Whether the first is showing is a `Bool` the
// AUTHOR holds, borrowed two-way - so opening the menu from code is `presented
// = true`, and a reader who swipes it away writes `false` back through the same
// binding.
//
//     @State private var menu = false
//
//     FlyoutPage($menu) {
//         MenuPage(section: $section, menu: $menu)  // the flyout
//     } detail: {
//         NavigationPage($path) { … } destination: { … }
//     }
//
// The PANE IS AN ORDINARY PAGE: the rows are whatever views the author writes, a
// row is a Button whose handler assigns state, and nothing about it - no item
// type, no template, no selection of its own - is the library's business.

/// A page holding two: one at the side and one that stays.
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
///         var page: any Page {
///             FlyoutPage($menu) {
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
///     struct MenuPage: ContentPage {
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
/// flyout that should stay open simply does not write the second.
///
/// **What the reader can do**, and it arrives as a write to the binding: a
/// swipe from the edge, a tap on the shaded detail page, the hamburger the
/// platform draws where those affordances exist. Each ends in
/// `isPresented` saying what is true - so the state and the screen cannot
/// disagree.
///
/// **On a wide screen there may be nothing to open.** The native host may keep
/// both halves visible; the binding then settles on `true`, so an application
/// that draws its own open button can hide it by reading the same value.
///
/// **What is deliberately NOT here:**
///
/// - A flyout ITEM type, a flyout template, a flyout header and footer. The
///   pane is a page; a header is a view at the top of it.
/// - A way to turn the flyout OFF while keeping the page it is on. A
///   `FlyoutPage` is made of its two pages - an application with nothing to put
///   in a pane does not use one.
/// - A shared overlay/split policy or gesture switch. Those are capabilities
///   of a particular native container. The host adapts its own presentation;
///   StateUI owns the two pages and their settled open state.
public struct FlyoutPage: Page, PageElement {
    /// The node this page describes.
    public var node: Node

    /// The node, as every element answers it.
    public var body: Node { node }

    /// A flyout over `detail`, shown when `isPresented` says so.
    ///
    /// - Parameter isPresented: whether the flyout is showing, borrowed
    ///   two-way. A swipe, a tap outside it or the platform's own button write
    ///   here.
    /// - Parameter flyout: the page that slides in. It must have a title.
    /// - Parameter detail: the page underneath, which is the application.
    public init(
        _ isPresented: Binding<Bool>,
        flyout: () -> Page,
        detail: () -> Page
    ) {
        node = Node(
            type: .flyoutPage,
            props: [.isPresented: .bool(isPresented.wrappedValue)],
            children: [
                Self.identified(flyout().body, as: Self.flyoutIdentity),
                Self.identified(detail().body, as: Self.detailIdentity),
            ])

        // The reader's own ways in and out - the edge swipe, the tap on the
        // dimmed detail page, the platform's hamburger - all end here, and only
        // once the gesture has FINISHED: an interactive swipe let go halfway
        // reports whatever it settled on, which is what the screen shows.
        //
        // Written only when it MOVED, the rule every binding in this library
        // follows: a host can report either direction, and a binding written
        // with the value it already holds would be a render nobody asked for.
        node.addHandler(.isPresentedChanged) {
            guard let presented = EventBuffer.current.value()?.bool,
                  presented != isPresented.wrappedValue else { return }

            isPresented.wrappedValue = presented
        }
    }

    // MARK: - Who the two pages are

    /// What the pane is called among its siblings.
    private static let flyoutIdentity = "flyout"

    /// And what the page under it is called.
    private static let detailIdentity = "detail"

    /// A page node wearing the identity the arrangement gives it.
    ///
    /// Identity here is what pairs a page with its half of the layout, so it
    /// belongs to the mechanism rather than to the author - the same rule a
    /// `NavigationPage` follows for the pages in its stack.
    private static func identified(_ node: Node, as identity: String) -> Node {
        var copy = node
        copy.id = identity
        return copy
    }
}
