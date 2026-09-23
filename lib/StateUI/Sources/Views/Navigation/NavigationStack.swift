// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The navigation stack: what is on the native stack is an array the author
// holds, and a back gesture the user completes shortens it.
// Design: docs/design/views/pages.md#the-stack-is-the-state

/// A page holding a native stack of pages, with a bar and a back affordance.
///
///     enum Route: Hashable {
///         case details(String)
///     }
///
///     struct MainWindow: Window {
///         @State private var path: [Route] = []
///
///         var page: any Page {
///             NavigationStack($path) {
///                 HomePage(path: $path)
///             } destination: { route in
///                 switch route {
///                 case .details(let id): DetailsPage(id: id)
///                 }
///             }
///         }
///     }
///
///     struct HomePage: ContentView {
///         @Binding var path: [Route]
///         @Environment private var page: PageSession
///
///         var content: any View {
///             Button("Open the first")
///                 .onClicked { path.append(.details("first")) }
///                 .onCreated { page.title = "Home" }
///         }
///     }
///
/// Push is `path.append(_:)`, pop is `path.removeLast()`, back to the root is
/// `path = []`, and a back gesture the user completes shortens the path. Hand
/// the root page the binding: a page that pushes has to be able to write it.
///
/// The first closure is the root, always there. The second is asked for a page
/// per element of `path`, in order; a `switch` over the route type makes the
/// compiler check that every route has a page.
///
/// The path can live anywhere a `Binding` can - `@State` on the window, as
/// above, or a model offered with `.environment(_:)` that names the moves:
///
///     final class Router {
///         @State var path: [Route] = []
///
///         func open(_ id: String) { path.append(.details(id)) }
///         func home() { path = [] }
///     }
///
///     NavigationStack(router.$path) { RoutedHomePage() } destination: { … }
///
/// A route may repeat: `[.level(1), .level(2), .level(2)]` holds two different
/// `.level(2)` pages. A route must be a value whose distinct values describe
/// differently (`String(describing:)`), so a class does not qualify.
///
/// `.onChanged(path)` observes every committed arrival and departure. The
/// title on the bar belongs to the top page; `.title` and `.icon` on the
/// stack name the whole stack where another container presents it.
public struct NavigationStack: Page, ModifiableElement, BarElement, PageElement, PageArrangement {
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
        root: () -> any Page,
        destination: (Route) -> any Page
    ) {
        var children: [Node] = [Self.identified(Node.page(root()), as: Self.rootIdentity)]

        for (depth, route) in path.wrappedValue.enumerated() {
            children.append(
                Self.identified(Node.page(destination(route)), as: Self.identity(depth: depth, route: route)))
        }

        node = Node(contract: NavigationStackContract.self, children: children)

        // The platform's way back, once committed, reports how deep the stack
        // now is above the root; the path only ever shortens to match.
        // Design: docs/design/views/pages.md#a-pop-report-only-shortens
        node.addHandler(NavigationStackContract.popped.token) {
            guard let depth = EventBuffer.current.value()?.int else { return }

            let routes = path.wrappedValue
            guard depth >= 0, depth < routes.count else { return }

            path.wrappedValue = Array(routes.prefix(depth))
        }
    }

    /// The root page's key, which no route's can equal: a route's carries its depth.
    private static let rootIdentity = "root"

    /// Who a pushed page is: its depth and its route together.
    /// Design: docs/design/views/pages.md#an-arrangement-keys-its-pages
    private static func identity(depth: Int, route: some Hashable) -> String {
        "\(depth)/\(String(describing: route))"
    }

    /// A page node wearing the key the stack gives it.
    private static func identified(_ node: Node, as identity: String) -> Node {
        var copy = node
        copy.id = identity
        return copy
    }
}

extension NavigationStack {
    /// The colour the bar draws on its background: the navigation title and
    /// the native navigation and toolbar affordances. Destructive actions keep
    /// the platform's warning colour.
    public func barForegroundColor(_ value: Color) -> NavigationStack {
        setValue(NavigationStackContract.barForegroundColor, value)
    }
}
