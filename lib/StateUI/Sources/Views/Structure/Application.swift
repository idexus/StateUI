// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The structure every host shows: Application, Scene, Window, Page.
// Design: docs/design/views/pages.md#application-scene-window-page

/// The application at the root of a StateUI tree.
///
/// Handed to `stateUIUseApp` once, at startup; the host then connects the
/// platform's application and scene lifecycle to it.
///
/// It declares its scene and nothing else. What the whole application is - its
/// styles, how its values move, what it keeps between launches - is its
/// `ApplicationSession`, written where the application is made:
///
///     struct NotesApp: Application {
///         @Environment private var application: ApplicationSession
///
///         init() {
///             application.styles = AppStyles.sheet
///             application.persistentKeys = [.lastNote]
///         }
///
///         var scene: any Scene { MainWindow() }
///     }
///
/// Write it in `init`: the kept state's keys are read as the application
/// registers, before the first view is built. The standard environment - the
/// device, the display, the locale - is known there already.
public protocol Application {
    /// What each session of the application is: its main window, the windows
    /// it opens beside it, and the state they share. See `Scene`.
    ///
    ///     var scene: any Scene { MainWindow() }                          // one window
    ///     var scene: any Scene { EditorScene().environment(library) }    // an editor's sessions
    ///
    /// The platform makes as many sessions as the user asks for.
    var scene: any Scene { get }
}

/// A window onto a page.
///
///     struct MainWindow: Window {
///         var page: any Page { MainPage() }
///     }
///
/// A type you declare, never a value you chain onto: `page` is its one
/// requirement, and it may hold `@State` of its own. What the window is as it
/// runs - its title, its frame, its title bar, the pages presented over it,
/// its lifecycle - is its `WindowSession`, in the environment of everything in
/// it:
///
///     struct MainPage: ContentView {
///         @Environment private var window: WindowSession
///
///         var content: any View {
///             VStack { … }
///                 .onCreated {
///                     window.title = "My Application"
///                     window.width = 1200
///                 }
///         }
///     }
///
/// A scene with several kinds of window declares each kind once and names
/// them in its `Windows`. What every view in a window needs is offered above
/// it, with `.environment(_:)` on the scene or on its `Windows`.
public protocol Window: Element, Scene {
    /// What the window shows: a `NavigationStack`, a `TabbedView`, a
    /// `SplitView`, or any other view - usually a `ContentView` of the
    /// application's own. Read again when a state it read changes.
    var page: any Page { get }
}

extension Window {
    /// A window alone is a scene of one window:
    /// `var scene: any Scene { MainWindow() }`.
    public var windows: Windows { Windows(main: { self }) }

    /// The window as a node: its page, and what hangs off it - its title bar
    /// and the pages presented over it.
    public var body: Node {
        let request = ElementSession(WindowSession.self) { WindowSession() }

        var node = composed(panel: nil) { request.held(as: WindowSession.self) }
        node.session = request
        return node
    }

    /// The same, for a window of a scene: the session it keeps, and a main
    /// window's inspector panel, both asked for inside the window's build.
    /// Design: docs/design/views/pages.md#a-window-is-a-placeholder
    func body(panel: (() -> Node?)?, session: WindowSession) -> Node {
        var node = composed(panel: panel) { session }

        // On the placeholder, so the window's own `@Environment` resolves it too.
        node.environments.append((key: ObjectIdentifier(WindowSession.self), object: session))

        return node
    }

    private func composed(
        panel: (() -> Node?)?,
        session: @escaping () -> WindowSession
    ) -> Node {
        Node.composed(self, type: String(reflecting: Self.self)) {
            let session = session()
            let overlay = Node.overlay(session.overlay, panel: panel?())

            // Its page, the title bar and modal stack, the overlay: one order.
            // Design: docs/design/views/pages.md#the-children-of-a-window
            var node = Node(
                contract: WindowContract.self,
                children: [Node.page(page)] + session.slots + (overlay.map { [$0] } ?? []))
            node.props = session.props

            // One handler per lifecycle report, never iterated from a collection.
            // Design: docs/design/views/pages.md#lifecycle-reports-one-by-one
            node.addHandler(WindowContract.created.token) { session.phase = .created }
            node.addHandler(WindowContract.activated.token) { session.phase = .activated }
            node.addHandler(WindowContract.deactivated.token) { session.phase = .deactivated }
            node.addHandler(WindowContract.stopped.token) { session.phase = .stopped }
            node.addHandler(WindowContract.resumed.token) { session.phase = .resumed }
            node.addHandler(WindowContract.destroying.token) { session.phase = .destroying }

            if let stack = session.modalStack { node.addHandler(WindowContract.modalPopped.token, stack.popped) }

            return node
        }
    }
}

extension Node {
    /// What a window lays over its page and the pages presented over it: the application's view, and a docked
    /// inspector's panel over that, each under a key of its own so it keeps its elements as the other comes and
    /// goes; nil for neither.
    /// Design: docs/design/views/pages.md#the-children-of-a-window
    static func overlay(_ view: (any View)?, panel: Node?) -> Node? {
        var layers: [Node] = []
        if var node = view?.body {
            node.key = "view"
            layers.append(node)
        }
        if var node = panel {
            node.key = "inspector"
            layers.append(node)
        }
        guard !layers.isEmpty else { return nil }

        var stack = ZStack().letsInputThrough(true).node
        stack.children = layers
        return Node(contract: OverlayContract.self, children: [stack])
    }
}

/// What a container shows as a screen: a window's `page`, a navigation
/// stack's root and destinations, a tab, either half of a split view, a
/// sheet.
///
/// Nobody conforms to it by hand. Every view is a page, and so is each
/// arrangement - `NavigationStack`, `TabbedView`, `SplitView` - which is not a
/// view and so stands only where a page stands.
///
/// A view shown as a page holds a `PageSession`, in the environment of
/// everything in it, carrying what the screen is - its title, its buttons,
/// its menus, its lifecycle:
///
///     struct MainPage: ContentView {
///         @Environment private var page: PageSession
///
///         var content: any View {
///             VStack { … }
///                 .onCreated { page.title = "Home" }
///         }
///     }
///
/// What `.onCreated` writes arrives with the page. A page asks things of the
/// container showing it through the same session, `page.hasNavigationBar =
/// false`; the bar's look belongs to the arrangement drawing it. An
/// arrangement is told its title and icon by modifier, from `PageElement`.
public protocol Page: Element {}

/// An arrangement: a page this library declares, shown as it is.
protocol PageArrangement: Page {}

extension Node {
    /// A view shown as a screen: an arrangement as it is, any other view on a
    /// page element of its own, which holds the view's `PageSession`.
    /// Design: docs/design/views/pages.md#a-page-around-a-view
    static func page(_ shown: any Page) -> Node {
        if shown is any PageArrangement { return shown.body }

        let content = shown.body
        let kind = (content.stateful?.viewType ?? content.type.name) + (content.id.map { "#\($0)" } ?? "")
        let request = ElementSession(PageSession.self) { PageSession() }

        var node = composed(ShownView(content: content), type: "StateUI.Page(\(kind))") {
            page(around: content, session: request.held(as: PageSession.self))
        }

        node.session = request
        return node
    }

    /// The page: the session's properties, its content first - so a page
    /// gaining a title view does not move its content - then what hangs off it.
    private static func page(around content: Node, session: PageSession) -> Node {
        var node = Node(contract: PageContract.self, children: [content] + session.slots)
        node.props = session.props

        node.addHandler(PageContract.appearing.token) { session.phase = .appearing }
        node.addHandler(PageContract.disappearing.token) { session.phase = .disappearing }
        node.addHandler(PageContract.navigatedTo.token) { session.phase = .navigatedTo }
        node.addHandler(PageContract.navigatingFrom.token) { session.phase = .navigatingFrom }
        node.addHandler(PageContract.navigatedFrom.token) { session.phase = .navigatedFrom }

        return node
    }
}

/// The view a page shows, held as a node so the view is compared on its own.
private struct ShownView {
    let content: Node
}

// Design: docs/design/views/pages.md#the-application-is-named-once
/// Names the application to the host.
///
/// The one line an app writes outside its own interface, in the function the
/// host calls by name at startup, in the app's own module:
///
///     @_cdecl("stateui_app_register")
///     public func stateui_app_register() {
///         stateUIUseApp(HelloWorldApp())
///     }
///
/// - Parameter application: the application, made here with a fresh
///   application session and kept for the life of the process, so `@State`
///   declared on it outlives every window.
public func stateUIUseApp(_ application: @autoclosure () -> Application) {
    Renderer.shared.setApplication(application())
}
