// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The navigation stack, owned by Swift.
//
// A MAUI NavigationPage keeps a stack of pages and draws a bar with a back
// button over whichever is on top. What is ON that stack is not the platform's
// business here: it is an array the AUTHOR holds, of the author's own type, and
// the host reconciles the native stack to whatever that array says.
//
//     enum Route: Hashable { case group(String), sample(String) }
//
//     @State private var path: [Route] = []
//
//     NavigationPage($path) {
//         HomePage()
//     } destination: { route in
//         switch route {
//         case .group(let id):  GroupPage(id: id)
//         case .sample(let id): SamplePage(id: id)
//         }
//     }
//
// Push is `path.append(...)`, pop is `path.removeLast()`, back to the root is
// `path = []`. There is no navigate call, no route string and no registry: the
// stack IS the state, so every question about where the application is has an
// answer that can be read, tested and serialized on this side.
//
// The gestures stay the platform's. A swipe-back on iOS and the system back on
// Android are cancellable, so nothing is said until one COMMITS; when it does,
// the host reports the depth that survived and the array is truncated to match.
// The next render then finds the native stack already the way it is described
// and does nothing - the same echo the flyout's binding carries.

/// A page holding a stack of pages, with a bar and a back button.
/// MAUI: NavigationPage.
///
/// A whole application, and it is the whole of one:
///
///     enum Route: Hashable {
///         case details(String)
///     }
///
///     struct HelloApp: Application {
///         func createWindow() -> Window { MainWindow() }
///     }
///
///     struct MainWindow: Window {
///         @State private var path: [Route] = []
///
///         var content: Page {
///             NavigationPage($path) {
///                 HomePage(path: $path)
///             } destination: { route in
///                 switch route {
///                 case .details(let id): DetailsPage(id: id)
///                 }
///             }
///         }
///     }
///
///     struct HomePage: ContentPage {
///         @Binding var path: [Route]
///
///         var title: String? { "Home" }
///
///         var content: Element {
///             Button("Open the first")
///                 .onClicked { path.append(.details("first")) }
///         }
///     }
///
/// Note what the root page takes: **the binding, handed down**. A page that
/// pushes has to be able to write the path, and the path belongs to whoever
/// declared it - `HomePage()` with nothing in the brackets compiles and then
/// has no way to navigate, which is the one wrong turn this API invites.
///
/// The first closure is the ROOT - the page that is always there, since a
/// native stack is never empty. The second is asked for a page per element of
/// `path`, in order, and being a `switch` over the author's own type it is the
/// compiler's business that every route has a page: a route that names nothing
/// does not compile, where a misspelled route string is a fault the user finds.
///
/// **Where the path comes from.** Anywhere a `Binding` does, and `@State` on
/// the window - as above - is the short answer. An application with navigation
/// of its own puts the array in a model and names the moves itself:
///
///     @StateClass
///     final class Router {
///         var path: [Route] = []
///
///         func open(_ id: String) { path.append(.details(id)) }
///         func home() { path = [] }
///     }
///
///     struct RoutedWindow: Window {
///         @State private var router = Router()
///
///         var environment: [AnyObject] { [router] }
///
///         var content: Page {
///             NavigationPage($router.path) {
///                 RoutedHomePage()
///             } destination: { … }
///         }
///     }
///
///     struct RoutedHomePage: ContentPage {
///         @Environment private var router: Router
///
///         var content: Element {
///             Button("Open the first").onClicked { router.open("first") }
///         }
///     }
///
/// `$router.path` is a binding into the model - the same `$` a `@State` uses,
/// reaching one property of it. Both halves of the model are needed: `@State`
/// keeps the one instance across renders, and `@StateClass` is what makes a
/// write to `path` ask for another one. The window's `environment` then hands
/// the router to every page under it, so nothing has to be threaded through
/// their initializers.
///
/// This library ships no router of its own on purpose: the names would be the
/// library's, and the array is the whole mechanism.
///
/// **A route may repeat.** `[.level(1), .level(2), .level(2)]` is a legal
/// stack, and the two `.level(2)` pages are different pages with `@State` of
/// their own: an element's identity here is its POSITION together with its
/// route, so neither one alone can confuse them.
///
/// **A route must be a VALUE, and distinct values must READ differently.**
/// Identity is rendered from `String(describing:)` - the same way `ForEach`
/// renders an item's - so an enum or a struct of values is right and a CLASS
/// is not: two instances of a class describe identically, and the stack would
/// take them for one page. This is the same rule `ForEach` states as "items
/// must be DISTINCT within their parent".
///
/// **What is deliberately NOT here**, so nobody goes looking:
///
/// - `CurrentPage` and `RootPage` are MAUI's read-only answers to "where am
///   I". The bound path already is that answer, on this side, before the host
///   has drawn anything.
/// - `PushAsync`, `PopAsync`, `PopToRootAsync` - assigning the path IS the
///   navigation, and a second way to do it is the thing this library refuses.
/// - MAUI's `Pushed`, `Popped` and `PoppedToRoot` events. The path is the one
///   channel: a view holding it writes `.onChanged(path) { … }` and hears
///   every arrival and departure, the ones the reader made included, as STATE
///   rather than as a notification that may or may not have been acted on.
/// - The page's own look - a padding, a background, a safe-area inset. A
///   NavigationPage draws nothing but its bar and whatever page is on top, so
///   the page on top carries all of that.
///
/// What IS on it: `BarElement`'s three bar colours; `PageElement`'s `.title`
/// and `.iconImageSource`, which name the whole stack where it is shown as an
/// ITEM of something else - a tab of a `TabbedPage`, usually; and
/// `PageElement`'s `.modalPresentationStyle`, for a whole stack presented as a
/// sheet. The title ON the bar is the top page's own.
public struct NavigationPage: Page, BarElement, PageElement {
    /// The node this page describes.
    public var node: Node

    /// The node, as every element answers it.
    public var body: Node { node }

    /// A stack over `path`, with `root` under it and `destination` above.
    ///
    /// - Parameter path: what is on the stack, ABOVE the root - the author's
    ///   own type, borrowed two-way. A completed back gesture truncates it.
    /// - Parameter root: the page under everything, built once and kept.
    /// - Parameter destination: the page for one route, asked in path order.
    public init<Route: Hashable>(
        _ path: Binding<[Route]>,
        root: () -> Page,
        destination: (Route) -> Page
    ) {
        var children: [Node] = [Self.identified(root().body, as: Self.rootIdentity)]

        for (depth, route) in path.wrappedValue.enumerated() {
            children.append(
                Self.identified(destination(route).body, as: Self.identity(depth: depth, route: route)))
        }

        node = Node(type: .navigationPage, children: children)

        // The platform's own way back - the arrow, the swipe, Android's system
        // gesture - arrives here, and only once it has COMMITTED: an
        // interactive swipe that is let go halfway pops nothing and says
        // nothing. The payload is how deep the stack is now, above the root.
        //
        // The guard only ever SHORTENS the path: a report as deep as the path
        // already is, or deeper, has been overtaken by another pop and would
        // otherwise put pages back. A report overtaken by a PUSH is not
        // recognized and truncates it - which is a real race and a narrow one
        // (the reader's back press has to land between a handler queuing a
        // push and that push being described), and it resolves the way the
        // reader's finger said. Recognizing it would mean numbering the
        // reports, which is a moving part this does not carry.
        node.addHandler(.popped) {
            guard let depth = EventBuffer.current.value()?.int else { return }

            let routes = path.wrappedValue
            guard depth >= 0, depth < routes.count else { return }

            path.wrappedValue = Array(routes.prefix(depth))
        }
    }

    // MARK: - Who a page on the stack is

    /// What the root page is called among its siblings, where no route can
    /// reach: a route's identity always carries its depth.
    private static let rootIdentity = "root"

    /// Who a pushed page is: its DEPTH and its ROUTE together.
    ///
    /// Neither half is enough. Depth alone would hand the page at index 1 -
    /// and the `@State` in it - to whatever route replaced it after a pop and
    /// a push. The route alone cannot tell two `.level(2)` pages apart, which
    /// a stack is entitled to hold. Rendered into the id namespace the way
    /// `ForEach` renders an item's identity, which is the same decision.
    private static func identity(depth: Int, route: some Hashable) -> String {
        "\(depth)/\(String(describing: route))"
    }

    /// A page node wearing the identity the stack gives it.
    ///
    /// Always the stack's, never the author's. `.id()` is a `VisualElement`
    /// modifier and a page is not a view, so there is none to write here - and
    /// the rule is the better one anyway: identity on a stack is what pairs a
    /// pop report with the page it popped, so it belongs to the mechanism. An
    /// ARRANGED list of pages is the one thing in this library identified this
    /// way, and `TabbedPage` and `ModalStack` do it to theirs too.
    private static func identified(_ node: Node, as identity: String) -> Node {
        var copy = node
        copy.id = identity
        return copy
    }
}
