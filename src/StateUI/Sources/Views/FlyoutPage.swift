// The flyout, owned by Swift.
//
// A MAUI FlyoutPage is two pages: one that slides in from the side and one the
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

/// A page holding two: one that slides in, one that stays. MAUI: FlyoutPage.
///
/// A whole application, and this is all of it:
///
///     enum Section: Hashable, CaseIterable { case today, archive }
///
///     struct DiaryApp: Application {
///         func createWindow() -> Window { MainWindow() }
///     }
///
///     struct MainWindow: Window {
///         @State private var section: Section = .today
///         @State private var menu = false
///
///         var content: Page {
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
///
///         var title: String? { "Sections" }        // REQUIRED - see below
///
///         var content: Element {
///             VStack {
///                 ForEach(Section.allCases, id: \.self) { which in
///                     Button("\(which)")
///                         .onClicked {
///                             section = which      // choose
///                             menu = false         // and close
///                         }
///                 }
///             }
///         }
///     }
///
/// Note what a row is: **a Button whose handler assigns state**. Choosing and
/// closing are two ordinary writes, in the order the author wants them, and a
/// flyout that should stay open simply does not write the second.
///
/// **The flyout page MUST have a title.** MAUI refuses a flyout without one -
/// it is what the platform draws where a title goes - and a `FlyoutPage` whose
/// flyout has none is reported by the host rather than shown.
///
/// **What the reader can do**, and it arrives as a write to the binding: a
/// swipe from the edge, a tap on the shaded detail page, the hamburger the
/// platform draws. Each is the platform's own gesture, and each ends in
/// `isPresented` saying what is true - so the state and the screen cannot
/// disagree.
///
/// **On a wide screen there may be nothing to open.** With
/// `.flyoutLayoutBehavior(.split)` both halves are simply there, and MAUI keeps
/// `IsPresented` true; the binding then says so, and an application that draws
/// its own "open the menu" button can hide it by reading the same value.
///
/// **What is deliberately NOT here:**
///
/// - A flyout ITEM type, a flyout template, a flyout header and footer. The
///   pane is a page; a header is a view at the top of it.
/// - A way to turn the flyout OFF while keeping the page it is on. A
///   `FlyoutPage` is made of its two pages - an application with nothing to put
///   in a pane does not use one.
/// - MAUI's `ShouldShowToolbarButton()`, which asks whether the hamburger is
///   drawn. It is the platform's answer to the layout it chose, and reading it
///   would be reading the screen rather than the state.
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
        // follows: MAUI raises this for our own assignment as readily as for a
        // finger, and a binding written with the value it already holds would
        // be a render nobody asked for.
        node.addHandler(.isPresentedChanged) {
            guard let presented = EventBuffer.current.value()?.bool,
                  presented != isPresented.wrappedValue else { return }

            isPresented.wrappedValue = presented
        }
    }

    // MARK: - How the two halves are laid out

    /// Whether the flyout slides OVER the detail page or sits beside it.
    /// MAUI: FlyoutPage.FlyoutLayoutBehavior.
    ///
    ///     FlyoutPage($menu) { … } detail: { … }
    ///         .flyoutLayoutBehavior(.split)
    ///
    /// The default is the platform's own answer, which is a drawer on a phone
    /// and side by side on a wide screen - usually what an application wants.
    public func flyoutLayoutBehavior(_ value: FlyoutLayoutBehavior) -> FlyoutPage {
        setValue(.flyoutLayoutBehavior, value.propValue)
    }

    /// Whether the reader can open the flyout by SWIPING.
    /// MAUI: FlyoutPage.IsGestureEnabled.
    ///
    /// False leaves the flyout reachable only from the application's own
    /// buttons and the platform's - which is what a detail page that scrolls
    /// sideways wants, the two gestures being the same one.
    public func isGestureEnabled(_ value: Bool) -> FlyoutPage {
        setValue(.isGestureEnabled, .bool(value))
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
