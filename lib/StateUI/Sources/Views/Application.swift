// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The stable shape every StateUI host materializes.
//
//     Application  ──scene──▶  Scene  ──windows──▶  Window  ──page──▶  Page  ──view──▶  the view tree
//
// An Application declares its scene, a Scene its windows, a Window its page -
// and that is ALL any of them declares. Each is a type, declared rather than
// constructed:
//
//     struct GalleryApp: Application {
//         var scene: any Scene { MainWindow() }
//     }
//
//     struct MainWindow: Window {
//         var page: any Page { MainPage() }
//     }
//
//     struct MainPage: ContentView {
//         var content: any View {
//             VStack { … }
//         }
//     }
//
// WHAT EACH ONE IS AS IT RUNS - the application's styles, a window's title and
// size, a page's title and buttons - is its SESSION's state, in the
// environment of everything under it and written like any state, usually from
// the `.onCreated` of what it shows: `ApplicationSession`, `SceneSession`,
// `WindowSession`, `PageSession`. So the tree is steered by `@State` and
// `@Environment` alone, and the one thing each type declares is what it is
// MADE of. See Types/HostEnvironment.swift and Types/PageSession.swift.

/// The application at the root of a StateUI tree.
///
/// Handed to `stateUIUseApp` once, at startup. A native or compatibility host
/// then connects the platform's application and scene lifecycle to it.
///
/// It declares its scene and nothing else. What the whole application IS - its
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
/// In `init`, because the host asks for the kept state's keys as the
/// application registers, before the first view is built. The standard
/// environment - the device, the display, the locale - is known there already.
public protocol Application {
    /// What each session of the application is: its main window, the windows
    /// it opens beside it, and the state they share. See `Scene`.
    ///
    ///     var scene: any Scene { MainWindow() }                          // one window
    ///     var scene: any Scene { EditorScene().environment(library) }    // an editor's sessions
    ///
    /// A window alone is a scene of one window, which is what most
    /// applications write. The platform makes as many as the reader asks for -
    /// the first at launch, another for every *File ▸ New Window*, every one
    /// the system restores at the next launch - and `application.openScene()`
    /// asks for one from the interface. Read when the application's tree is
    /// built - the first time, and again when a state it read changes - so a
    /// scene sees state changes without anything being invalidated by hand.
    ///
    /// A host maps those sessions onto the independent scene or window
    /// identities its native application model provides. On a single-window
    /// device it may refuse another session with `WindowError.unsupported`.
    var scene: any Scene { get }
}

/// A window onto a page.
///
///     struct MainWindow: Window {
///         var page: any Page { MainPage() }
///     }
///
/// Written the way a view of the application's own is: a type you DECLARE,
/// never a value you chain onto, and `page` is its one requirement. What the window IS as
/// it runs - what it is called, where it is and how big, its title bar, the
/// pages presented over it, where it stands in its life - is its
/// `WindowSession`, in the environment of everything in it and written like
/// any state:
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
/// A window is a type, so it is also a place to put things - it holds
/// `@State` of its own. A scene with several kinds says each kind once
///
///     struct DocumentWindow: Window { … }
///     struct FontsWindow: Window { … }
///
/// and its `Windows` names them - the main one, and the groups beside
/// it. A window alone is a scene of one window, `var scene: any Scene {
/// MainWindow() }`. The ARRANGEMENT belongs here too: a window's `page` is
/// where a `NavigationStack` over a path, a `TabbedView` over a selection or a
/// `SplitView` over a menu is written, so which windows a scene has open and
/// how each of them moves are one declaration apiece. What reaches everything
/// in a window is offered above it - `.environment(_:)` on the scene the
/// application declares, or on the scene's `Windows` for every window of the
/// scene - and what reaches a branch, on a view in it.
public protocol Window: Element, Scene {
    /// What the window shows - a `NavigationStack` for an app that pushes and
    /// pops, a `TabbedView` for tabs, a `SplitView` for a menu beside the page,
    /// any other view for one screen - usually a `ContentView` of the
    /// application's own, which the window shows on a page.
    ///
    /// The only thing a window must say - read as the window is built, and
    /// again when what it was built with or a state it read changes; otherwise
    /// the window is carried whole.
    var page: any Page { get }
}

extension Window {
    /// A window alone is a scene of one window - which is what an application
    /// with nothing to open beside its window says:
    ///
    ///     var scene: any Scene { MainWindow() }
    public var windows: Windows { Windows(main: { self }) }

    /// The window as a node: its page, and whatever hangs off it beside.
    ///
    /// A placeholder, exactly like a composed view's, so that a window declared as a type
    /// may hold `@State` of its own and be rebuilt on its own when that state
    /// changes. A window shown ALONE, outside every scene, keeps a session of
    /// its own on its element, the way a page does; a scene's windows are
    /// handed theirs by the scene, which keeps them. See Core/Stateful.swift
    /// and Core/ElementSession.swift.
    public var body: Node {
        let request = ElementSession(WindowSession.self) { WindowSession() }

        var node = composed(panel: nil) { request.held(as: WindowSession.self) }
        node.session = request
        return node
    }

    /// The same, for a window of a scene - with the session the scene keeps
    /// for it, and for a main window the panel its scene's inspector docks in.
    /// Both are asked for INSIDE the window's build, so the window is what
    /// builds again when either moves. See Core/Scenes.swift and
    /// Views/Inspector.swift.
    ///
    /// - Parameters:
    ///   - panel: what docks over the window, asked for as it builds.
    ///   - session: the window's session, offered to everything in it - the
    ///     window's own `@Environment` included.
    func body(panel: (() -> Node?)?, session: WindowSession) -> Node {
        var node = composed(panel: panel) { session }

        // Offered on the placeholder, so the window's own `@Environment`
        // resolves it as well as everything under it.
        node.environments.append((key: ObjectIdentifier(WindowSession.self), object: session))

        return node
    }

    /// The window's node, over whichever session it is handed - asked for as
    /// the window builds.
    private func composed(
        panel: (() -> Node?)?,
        session: @escaping () -> WindowSession
    ) -> Node {
        Node.composed(self, type: String(reflecting: Self.self)) {
            let session = session()
            let overlay = panel?()

            // Its page first, then what hangs off it - the title bar and the
            // modal stack, read off the session as the window builds, so the
            // window is what builds again when either is written - and the
            // inspector's panel last. The host reads them by TYPE, so the order
            // is this side's to settle, and one order is what makes the
            // window's children the same list in every run.
            var node = Node(
                type: .window, props: session.props,
                children: [Node.page(page)] + session.slots + (overlay.map { [$0] } ?? []))

            // Where the window stands, as its platform window reports it -
            // written out one by one rather than walked over a collection: the
            // wire is deterministic, and a Dictionary or a Set iterated into a
            // message differs between two instances inside one run. See
            // Core/Wire.swift.
            node.addHandler(.created) { session.phase = .created }
            node.addHandler(.activated) { session.phase = .activated }
            node.addHandler(.deactivated) { session.phase = .deactivated }
            node.addHandler(.stopped) { session.phase = .stopped }
            node.addHandler(.resumed) { session.phase = .resumed }
            node.addHandler(.destroying) { session.phase = .destroying }

            // The report that a modal has GONE, which is the window's because
            // the stack is - see ModalStack.swift.
            if let stack = session.modalStack { node.addHandler(.modalPopped, stack.popped) }

            return node
        }
    }
}

extension Node {
    /// A view laid over a whole window, above its page - the slot an
    /// inspector's panel is. The host lays it over the platform's own window,
    /// and a touch its views do not take goes through to the page.
    static func overlay(_ view: Element) -> Node {
        Node(type: .overlay, children: [view.body])
    }
}

/// What a container shows as a screen: a window's `page`, a navigation
/// stack's root and destinations, a tab, either half of a split view, a
/// sheet.
///
/// Nobody conforms to it by hand. Every view is a page - usually a
/// `ContentView` of the application's own - and so is each ARRANGEMENT: a
/// `NavigationStack`, a `TabbedView`, a `SplitView`. An arrangement is not a
/// view, so it stands only where a page stands: a stack written inside a
/// `VStack` does not compile.
///
/// The container puts a view it shows on a page, which carries what a screen
/// IS - its title, its buttons, its menus, where it stands in its life - as
/// the `PageSession` in the environment of the view and of everything in it:
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
/// What `.onCreated` writes is in the message that brings the page, so the
/// page arrives with its title and its buttons. A page also says what it asks
/// of the CONTAINER showing it, through the same session:
/// `page.hasNavigationBar = false`. What the BAR looks like is not a page's at
/// all: it belongs to the arrangement drawing it - see `barBackgroundColor` on
/// `NavigationStack` and `TabbedView`.
///
/// An arrangement is a page already and is shown as it is. It is told what it
/// is by modifier, `.title("Stack")`, from `PageElement`.
public protocol Page: Element {}

/// An arrangement: a page this library declares, shown as it is.
protocol PageArrangement: Page {}

extension Node {
    /// A view shown as a screen: an arrangement as it is, any other view on a
    /// page of its own.
    ///
    /// The page is an element around the view, holding the session for its
    /// life - kept while the same view stands there, the same kind under the
    /// same explicit id, and made afresh for another. The view stays the
    /// element it is, with its state, its inputs and whatever was written on
    /// it, one level down - so a write to the session builds the page again
    /// and carries the view whole.
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

    /// The page itself: the session's properties, what it shows, and whatever
    /// hangs off it besides - the content first, so a page that gained a title
    /// view does not look to the differ as though its content moved.
    private static func page(around content: Node, session: PageSession) -> Node {
        var node = Node(type: .page, props: session.props, children: [content] + session.slots)

        // Where the page stands, as the platform reports it - one by one
        // rather than over a collection, the window's rule: the wire is
        // deterministic and nothing may iterate a Dictionary into a message.
        node.addHandler(.appearing) { session.phase = .appearing }
        node.addHandler(.disappearing) { session.phase = .disappearing }
        node.addHandler(.navigatedTo) { session.phase = .navigatedTo }
        node.addHandler(.navigatingFrom) { session.phase = .navigatingFrom }
        node.addHandler(.navigatedFrom) { session.phase = .navigatedFrom }

        return node
    }
}

/// The view a page shows, as the page's element holds it: a node, which is
/// interface rather than an input anything compares - so the page is built
/// with its parent, and the view inside is compared on its own.
private struct ShownView {
    let content: Node
}

/// Names the application to the host.
///
/// The one line an app writes outside its own interface, and it goes in the
/// function the host calls by name at startup:
///
///     @_cdecl("stateui_app_register")
///     public func stateui_app_register() {
///         stateUIUseApp(HelloWorldApp())
///     }
///
/// That function lives in the APP's module and cannot move into this library:
/// on Android and Windows the app is a separate native library, and nothing in
/// it runs until something calls into it by name.
///
/// - Parameter application: the application, made HERE - after what an earlier
///   one wrote into the application's session has been forgotten, so its
///   `init` starts from nothing - and kept for as long as the process lives,
///   so `@State` declared on it is the state that outlives every window.
public func stateUIUseApp(_ application: @autoclosure () -> Application) {
    Renderer.shared.setApplication(application())
}
