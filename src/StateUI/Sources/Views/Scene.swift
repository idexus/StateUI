// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How an application is laid out in windows.
//
//     Application ──scene──▶ Scene ──windows──▶ the main window, and the groups beside it
//
// A SCENE is one session of the application: a main window, the smaller
// windows that serve it - an inspector, a palette, a document of its own - and
// the state all of them share. An application declares ONE scene, and the
// platform makes as many of it as the reader asks for: the first at launch,
// another for every *File ▸ New Window*, and every one that was open when the
// system restores the application's windows at the next launch.
//
//     struct GalleryApp: Application {
//         @State private var library = Library()              // every session's
//
//         var scene: any Scene { GalleryScene().environment(library) }
//     }
//
//     struct GalleryScene: Scene {
//         @State private var nav = Navigation()                // this session's
//
//         var windows: Windows {
//             Windows {
//                 WindowGroup(.fonts) { FontsWindow() }
//                 WindowGroup(.document, for: UUID.self) { $id in DocumentWindow(id: id) }
//             } main: {
//                 MainWindow()
//             }
//             .environment(nav)
//         }
//     }
//
// What follows from that shape is the whole of the model:
//
// - A session's STATE is its scene type's own `@State`: each session has its
//   own, and every window of the session reads it - offered with
//   `.environment`, or handed in as a binding.
// - A window of a group belongs to its scene. It opens with the scene's
//   session - `@Environment var scene: SceneSession`, then
//   `scene.openWindow(.fonts)` - it closes with its scene, it may hide while
//   another scene is in front, and it is never what *File ▸ New Window* makes.
// - What the system restores is what was open: each scene comes back with the
//   windows it had, and with the values its `@State(sceneKey:)` held.
//
// Which scenes are open is this library's to hold, never the author's - see
// Core/Scenes.swift.

/// One session of the application: its main window, the windows it opens
/// beside it, and the state they share. This library's own - MAUI has windows
/// and nothing above them.
///
///     struct EditorScene: Scene {
///         @State private var document = Document()
///
///         var windows: Windows {
///             Windows {
///                 WindowGroup(.fonts) { FontsWindow() }
///             } main: {
///                 EditorWindow()
///             }
///             .environment(document)
///         }
///     }
///
/// **A window is a scene of one window**, which is what an application with
/// nothing to open beside its window writes:
///
///     struct HelloApp: Application {
///         var scene: any Scene { MainWindow() }
///     }
///
/// A scene holds `@State` the way a window or a page does, and holds it ONCE
/// PER SESSION: a second *File ▸ New Window* is a second instance of the same
/// type, with state of its own. What every session shares belongs to the
/// `Application`, and reaches a scene through `.environment(_:)`. What is DONE
/// to a scene as it runs - opening a window in it, closing it - is its
/// `SceneSession`'s, in the environment of every view in it.
public protocol Scene {
    /// The scene's windows - its main one, and the groups it may open beside
    /// it. Read as the scene is built, and again when what it was built with
    /// or a state it read changes, so which groups there are and what the main
    /// window is can depend on state.
    var windows: Windows { get }
}

extension Scene {
    /// Offers an object to every window of every session of this scene,
    /// resolved by TYPE the way `.environment` on a view is - which is how the
    /// application's own state reaches its scenes.
    ///
    ///     var scene: any Scene { GalleryScene().environment(library) }
    ///
    /// A nearer `.environment()` of the same type - on `Windows`, or on a
    /// view inside - overrides it for its own branch.
    public func environment<Value: AnyObject>(_ object: Value) -> Scene {
        OfferingScene(base: self, key: ObjectIdentifier(Value.self), object: object)
    }
}

/// A scene with an object offered to everything in it.
struct OfferingScene: Scene {
    /// The scene the object is offered to.
    let base: Scene

    /// The type the object answers for.
    let key: ObjectIdentifier

    /// The object.
    let object: AnyObject

    var windows: Windows { base.windows }
}

/// A scene's windows: its MAIN window, and the GROUPS of windows it may open
/// beside it. This library's own.
///
///     Windows {
///         WindowGroup(.fonts) { FontsWindow() }
///     } main: {
///         if loading { LoadingWindow() } else { MainWindow() }
///     }
///
/// The main window IS the scene on screen: it opens with the scene, and the
/// reader closing it ends the scene and every window of its groups with it.
/// It is ONE window whatever type it is written as - the `if` above changes
/// what that window shows, and the platform's window stays where it is.
public struct Windows {
    /// The kinds of window the scene may open beside its main one.
    let groups: [WindowGroup]

    /// The main window.
    let main: Window

    /// What `.environment(_:)` offered every window of the scene.
    var environments: [(key: ObjectIdentifier, object: AnyObject)] = []

    /// A main window, and the groups of windows the scene may open beside it.
    ///
    /// - Parameters:
    ///   - groups: one `WindowGroup` per kind of window, and an `if` for a kind
    ///     only some scenes declare.
    ///   - main: the main window - an `if` choosing between two is allowed,
    ///     and swaps what the one window shows.
    public init(
        @WindowGroupBuilder _ groups: () -> [WindowGroup],
        @WindowBuilder main: () -> Window
    ) {
        self.groups = groups()
        self.main = main()
    }

    /// A main window and nothing to open beside it.
    ///
    /// - Parameter main: the main window.
    public init(@WindowBuilder main: () -> Window) {
        self.init({}, main: main)
    }

    /// Offers an object to every window of the scene - the main one and those
    /// beside it - resolved by TYPE, the way `.environment` on a view is. Which
    /// is how a session's windows share one context:
    ///
    ///     @State private var nav = Navigation()
    ///
    ///     var windows: Windows {
    ///         Windows { … } main: { MainWindow() }
    ///             .environment(nav)
    ///     }
    public func environment<Value: AnyObject>(_ object: Value) -> Windows {
        var copy = self
        copy.environments.append((key: ObjectIdentifier(Value.self), object: object))
        return copy
    }
}

/// One kind of window a scene opens beside its main one: ONE window of it,
/// or - given `for:` - one per value. This library's own.
///
///     WindowGroup(.fonts) { FontsWindow() }
///     WindowGroup(.document, for: UUID.self) { $id in DocumentWindow(id: id) }
///
/// The group says what the window IS; the scene's session says when it opens:
///
///     @Environment private var scene: SceneSession
///
///     Button("Fonts").onClicked { try await scene.openWindow(.fonts) }
///     Button("Open").onClicked { try await scene.openWindow(.document, value: id) }
///
/// A window of a group belongs to its scene: it closes with the scene, it
/// may hide while another scene is in front (`autoHide`) or float above the
/// application's windows (`floatsOnTop`), the Window menu on Mac Catalyst
/// never lists it - that lists the scenes, by their main windows - and it is
/// never what *File ▸ New Window* makes, which opens a scene. When the system restores the
/// application's windows, it comes back to its scene for the same value, which
/// is why the value is `Codable`: it is written down while the application is
/// not running.
///
/// **Mac Catalyst, iPad and Windows** open a window for each; a phone has one
/// window, and a session's `openWindow` there throws `WindowError.unsupported`.
public struct WindowGroup {
    /// The kind of window.
    let type: WindowType

    /// The type of value the group opens one window per - nothing for a group
    /// that opens one.
    let valueType: Any.Type?

    /// The window for one that is open, in the scene that has it open.
    let make: (_ opened: OpenedWindow, _ record: SceneRecord) -> Window

    /// A value read back out of the text it was written down as - what a
    /// window the system restored is opened for again.
    let restore: (_ text: String) -> AnyHashable?

    /// Whether its windows hide while another scene is in front.
    var hides = false

    /// Whether its windows float above the application's other windows.
    var floats = false

    /// A group that opens ONE window, in any scene that declares it.
    ///
    ///     WindowGroup(.debugInspector) { DebugInspector() }
    ///
    /// - Parameters:
    ///   - type: what a session's `openWindow` opens it by.
    ///   - window: the window.
    public init(_ type: WindowType, @WindowBuilder window: @escaping () -> Window) {
        self.type = type
        valueType = nil
        make = { _, _ in window() }
        restore = { _ in nil }
    }

    /// A group that opens one window PER VALUE - a document per document, an
    /// inspector per item.
    ///
    ///     WindowGroup(.document, for: UUID.self) { $id in DocumentWindow(id: id) }
    ///
    /// The window is handed a binding to its own value: reading it says which
    /// value the window is for, and writing it makes the same window about
    /// another - which is also what the system restores it for.
    ///
    /// - Parameters:
    ///   - type: what a session's `openWindow` opens one by.
    ///   - value: the type of value one window stands for - anything
    ///     `Codable` and `Hashable`, so the platform can write it down.
    ///   - window: the window for one value.
    public init<Value: Codable & Hashable & SendableMetatype>(
        _ type: WindowType,
        for value: Value.Type,
        @WindowBuilder window: @escaping (Binding<Value>) -> Window
    ) {
        self.type = type
        valueType = Value.self
        make = { opened, record in
            // The value as it was when the scene was built, and a write that
            // retargets THIS window: the scene reads what it has open, so the
            // write builds it again with the value it now stands for.
            let standing = opened.value?.base as! Value

            let binding = Binding<Value>(
                get: { standing },
                set: { record.retarget(opened.serial, to: $0) })

            return window(binding)
        }
        restore = { text in ValueText.read(Value.self, from: text).map(AnyHashable.init) }
    }

    /// Whether the group's windows hide while another scene of the
    /// application is the one in front - and come back when their own is.
    /// Mac Catalyst's; elsewhere they stay where they are.
    ///
    ///     WindowGroup(.fonts) { FontsWindow() }
    ///         .autoHide(true)
    public func autoHide(_ hides: Bool) -> WindowGroup {
        var copy = self
        copy.hides = hides
        return copy
    }

    /// Whether the group's windows float above the application's other
    /// windows - a tool that stays in sight over the main window it serves
    /// rather than going under it as soon as the reader clicks there. They
    /// float while the application is in front and go while another one is.
    /// Mac Catalyst's; elsewhere they stand where the platform puts them.
    ///
    ///     WindowGroup(.fonts) { FontsWindow() }
    ///         .floatsOnTop(true)
    public func floatsOnTop(_ floats: Bool) -> WindowGroup {
        var copy = self
        copy.floats = floats
        return copy
    }
}

/// What kind of window a group opens - the name a scene declares one under,
/// and a session's `openWindow` opens one by. This library's own.
///
///     extension WindowType {
///         static let fonts = WindowType("fonts")
///         static let document = WindowType("document")
///     }
///
/// Declared the way every vocabulary in this library is, as static members on
/// an extension. The name is written down with every window the system may
/// restore, so it belongs to the application and should not change between
/// its versions.
public struct WindowType: Hashable, Sendable, CustomStringConvertible {
    /// The name - what is written down with a window of this kind.
    public let name: String

    /// A kind of window, by its name.
    ///
    /// - Parameter name: the application's own name for it.
    public init(_ name: String) {
        self.name = name
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }

    /// The inspector that shows what every render costs and builds - see
    /// `DebugInspector`, which is its window.
    ///
    ///     WindowGroup(.debugInspector) { DebugInspector() }
    public static let debugInspector = WindowType("stateui.debugInspector")
}

/// Why a window or a scene was not opened or closed - what a session's
/// `openWindow`, `closeWindow` and `close()` throw, and
/// `ApplicationSession.openScene()`.
public enum WindowError: Error, Equatable, Sendable {
    /// It is open already: opening what is open is refused, and says so.
    case alreadyOpen

    /// It is not open.
    case notOpen

    /// The session is not an open scene's: the one a view outside every scene
    /// reads, or one whose scene has ended.
    case noScene

    /// The scene declares no group of this kind.
    case undeclared(WindowType)

    /// The group is declared for another value: it opens one window and was
    /// given a value, or opens one per value and was given none, or a value of
    /// another type.
    case wrongValue(WindowType)

    /// The platform opens no second window - a phone.
    case unsupported
}

/// Builds the one window a scene's `main:` or a group's closure answers - an
/// `if` choosing between two being the one thing it adds to a plain return.
@resultBuilder
public enum WindowBuilder {
    /// A window written as a statement.
    public static func buildExpression(_ window: Window) -> Window { window }

    /// The one window the closure holds.
    public static func buildBlock(_ window: Window) -> Window { window }

    /// The `if` branch of an if/else.
    public static func buildEither(first window: Window) -> Window { window }

    /// The `else` branch.
    public static func buildEither(second window: Window) -> Window { window }

    /// What an `if #available(…)` block builds.
    public static func buildLimitedAvailability(_ window: Window) -> Window { window }
}

/// Builds a scene's groups - one per statement, and an `if` for a group only
/// some scenes declare.
@resultBuilder
public enum WindowGroupBuilder {
    /// A group written as a statement.
    public static func buildExpression(_ group: WindowGroup) -> [WindowGroup] { [group] }

    /// The statements of the closure, in the order they are written.
    public static func buildBlock(_ groups: [WindowGroup]...) -> [WindowGroup] {
        groups.flatMap { $0 }
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ groups: [WindowGroup]?) -> [WindowGroup] { groups ?? [] }

    /// The `if` branch of an if/else.
    public static func buildEither(first groups: [WindowGroup]) -> [WindowGroup] { groups }

    /// The `else` branch.
    public static func buildEither(second groups: [WindowGroup]) -> [WindowGroup] { groups }

    /// What an `if #available(…)` block builds.
    public static func buildLimitedAvailability(_ groups: [WindowGroup]) -> [WindowGroup] {
        groups
    }
}
