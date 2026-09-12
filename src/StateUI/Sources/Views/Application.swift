// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How an application opens: MAUI's own types, with one above the window.
//
//     Application  ──scene──▶  Scene  ──windows──▶  Window  ──page──▶  Page  ──content──▶  the view tree
//
// An Application declares its scene, a Scene its windows, a Window its page, a
// ContentPage its content - and that is ALL any of them declares. Each is a
// type, declared rather than constructed:
//
//     struct GalleryApp: Application {
//         var scene: any Scene { MainWindow() }
//     }
//
//     struct MainWindow: Window {
//         var page: any Page { MainPage() }
//     }
//
//     struct MainPage: ContentPage {
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

/// The application. MAUI: Application.
///
/// Handed to `stateUIUseApp` once, at startup - the Swift half of MAUI's
/// `builder.UseMauiApp<App>()`.
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
    /// **iPad, Mac Catalyst and Windows** open more than one; a phone shows
    /// one. On iOS and Mac Catalyst the app has to be set up for SCENES as
    /// well, and every piece of that fails silently:
    /// `UIApplicationSupportsMultipleScenes` and the full scene manifest in
    /// Info.plist, the app's own registered `SceneDelegate :
    /// MauiUISceneDelegate`, and all four iPad orientations. Miss one and the
    /// first window opens BLANK or the second is refused, with nothing said
    /// either way. Windows never asks for one: a second launch there is a
    /// second PROCESS, and a new session is `application.openScene()`.
    var scene: any Scene { get }
}

/// A window onto a page. MAUI: Window.
///
///     struct MainWindow: Window {
///         var page: any Page { MainPage() }
///     }
///
/// Written the way a PAGE is written here: a type you DECLARE, never a value
/// you chain onto, and `page` is its one requirement. What the window IS as
/// it runs - what it is called, where it is and how big, its title bar, the
/// pages presented over it, where it stands in its life - is its
/// `WindowSession`, in the environment of everything in it and written like
/// any state:
///
///     struct MainPage: ContentPage {
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
/// where a `NavigationPage` over a path, a `TabbedPage` over a selection or a
/// `FlyoutPage` over a menu is written, so which windows a scene has open and
/// how each of them moves are one declaration apiece. What reaches everything
/// in a window is offered above it - `.environment(_:)` on the scene the
/// application declares, or on the scene's `Windows` for every window of the
/// scene - and what reaches a branch, on a view in it.
public protocol Window: Element, Scene {
    /// What the window shows - a `NavigationPage` for an app that pushes and
    /// pops, a `TabbedPage` for tabs, a `FlyoutPage` for a menu beside the page,
    /// a `ContentPage` for one screen. MAUI: Window.Page.
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
    /// A placeholder, exactly like a page's, so that a window declared as a type
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
                children: [page.body] + session.slots + (overlay.map { [$0] } ?? []))

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

/// A screenful of interface. MAUI: Page.
///
/// What a window shows, what a navigation stack holds, what a tab is - and it
/// asks nothing else, which is the whole of this protocol.
///
/// There are TWO KINDS, and the difference is who writes the type. A page an
/// author WRITES conforms to `ContentPage`: it declares its content, and what
/// it IS - its title, its buttons - is its `PageSession`'s state. A page an
/// author CONSTRUCTS is a value this library declares - `NavigationPage($path)
/// { … }`, `TabbedPage(tabs) { … }`, `FlyoutPage($open) { … }` - and a
/// constructor's result is told what it is by MODIFIER: `.title("Stack")`,
/// from `PageElement`.
///
/// Which is why nothing is declared here: a property declared on `Page` is one
/// every CONSTRUCTED page would wear without being able to answer it.
public protocol Page: Element {}

/// A page showing a single view. MAUI: ContentPage.
///
/// What a page SHOWS is its one requirement. What it IS - what it is called,
/// its buttons, how it is presented, where it stands in its life - is its
/// `PageSession`, in the environment of the page and of everything in it, and
/// written like any state:
///
///     struct MainPage: ContentPage {
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
/// of the CONTAINER showing it - MAUI's attached properties, written on the
/// page itself - through the same session:
/// `page.navigationPageHasNavigationBar = false`. What the BAR looks like is
/// not a page's at all: it belongs to the arrangement drawing it - see
/// `barBackgroundColor` on `NavigationPage` and `TabbedPage`.
public protocol ContentPage: Page {
    /// What the page shows. One view - put a layout here for more than one.
    ///
    /// The only thing a page must say - read as the page is built, and again
    /// when what it was built with or a state it read changes; otherwise the
    /// page is carried whole.
    var content: any View { get }
}

extension ContentPage {
    /// The page as a node: its session's properties, its content, and whatever
    /// hangs off it besides.
    ///
    /// A placeholder, like ContentView's, and for one reason more: the page's
    /// session is the ELEMENT's - made the first time the page is built and
    /// handed back on every build after - so a page, a value its parent makes
    /// afresh every time the parent builds, keeps one for its life, and its
    /// title view, buttons and menus are read off it as the page builds. See
    /// Core/Stateful.swift and Core/ElementSession.swift.
    public var body: Node {
        let request = ElementSession(PageSession.self) { PageSession() }

        var node = Node.composed(self, type: String(reflecting: Self.self)) {
            let session = request.held(as: PageSession.self)

            // The content first, so a page that gained a title view does not
            // look to the differ as though its content moved.
            var node = Node(
                type: .contentPage, props: session.props, children: [content.body] + session.slots)

            // Where the page stands, as the platform reports it - one by one
            // rather than over a collection, the window's rule: the wire is
            // deterministic and nothing may iterate a Dictionary into a
            // message.
            node.addHandler(.appearing) { session.phase = .appearing }
            node.addHandler(.disappearing) { session.phase = .disappearing }
            node.addHandler(.navigatedTo) { session.phase = .navigatedTo }
            node.addHandler(.navigatingFrom) { session.phase = .navigatingFrom }
            node.addHandler(.navigatedFrom) { session.phase = .navigatedFrom }

            return node
        }

        node.session = request
        return node
    }
}

/// Names the application to the host. MAUI: `builder.UseMauiApp<App>()`.
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
