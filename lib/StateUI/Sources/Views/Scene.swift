// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How an application is laid out in windows: one scene type, as many sessions
// of it as the user opens, each a main window and the groups beside it.
// Design: docs/design/views/pages.md#scenes

/// One session of the application: its main window, the windows it opens
/// beside it, and the state they share.
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
/// A window is a scene of one window - what an application with nothing to
/// open beside it writes: `var scene: any Scene { MainWindow() }`.
///
/// A scene holds `@State` once per session: a second *File ▸ New Window* is a
/// second instance with state of its own. What every session shares belongs
/// to the `Application` and reaches a scene through `.environment(_:)`.
/// Opening and closing its windows is its `SceneSession`'s, in the
/// environment of every view in it.
public protocol Scene {
    /// The scene's windows: its main one, and the groups it may open beside
    /// it. Read again when a state it read changes.
    var windows: Windows { get }
}

extension Scene {
    /// Offers an object to every window of every session of this scene,
    /// resolved by type the way `.environment` on a view is.
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

/// A scene's windows: its main window, and the groups of windows it may open
/// beside it.
///
///     Windows {
///         WindowGroup(.fonts) { FontsWindow() }
///     } main: {
///         if loading { LoadingWindow() } else { MainWindow() }
///     }
///
/// The main window is the scene on screen: it opens with the scene, and the
/// user closing it ends the scene and every window of its groups. It is one
/// window whatever type it is written as - the `if` above changes what that
/// window shows.
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

    /// Offers an object to every window of the scene, resolved by type the way
    /// `.environment` on a view is - how a session's windows share one context:
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

/// One kind of window a scene opens beside its main one: one window of it,
/// or - given `for:` - one per value.
///
///     WindowGroup(.fonts) { FontsWindow() }
///     WindowGroup(.document, for: UUID.self) { $id in DocumentWindow(id: id) }
///
/// The group says what the window is; the scene's session says when it opens:
///
///     @Environment private var scene: SceneSession
///
///     Button("Fonts").onClicked { try await scene.openWindow(.fonts) }
///     Button("Open").onClicked { try await scene.openWindow(.document, value: id) }
///
/// A window of a group belongs to its scene: it closes with the scene, and the
/// platform restores it to its scene for the same value, which is why the
/// value is `Codable`. A host without independent windows refuses
/// `openWindow` with `WindowError.unsupported`.
public struct WindowGroup {
    /// The kind of window.
    let type: WindowType

    /// The type of value the group opens one window per; nil for one window.
    let valueType: Any.Type?

    /// The window for one that is open, in the scene that has it open.
    let make: (_ opened: OpenedWindow, _ record: SceneRecord) -> Window

    /// A value read back from its text: what a restored window is opened for.
    let restore: (_ text: String) -> AnyHashable?

    /// Whether its windows hide while another scene is in front.
    var hides = false

    /// Whether its windows float above the application's other windows.
    var floats = false

    /// A group that opens one window, in any scene that declares it.
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

    /// A group that opens one window per value - a document per document, an
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
            // The value the scene was built with; a write retargets this window,
            // and the scene, which reads what it has open, builds it again.
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
    /// A host without that native policy leaves the windows visible.
    ///
    ///     WindowGroup(.fonts) { FontsWindow() }
    ///         .hidesWhenInactive(true)
    public func hidesWhenInactive(_ hides: Bool) -> WindowGroup {
        var copy = self
        copy.hides = hides
        return copy
    }

    /// Whether the group's windows float above the application's other
    /// windows - a tool that stays in sight over the main window it serves -
    /// while the application is in front. A host without native window levels
    /// leaves their order to the platform.
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
/// and a session's `openWindow` opens one by.
///
///     extension WindowType {
///         static let fonts = WindowType("fonts")
///         static let document = WindowType("document")
///     }
///
/// The name is written down with every window the system may restore, so it
/// should not change between versions of the application.
public struct WindowType: Hashable, Sendable, CustomStringConvertible, HostRepresentable {
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

    /// The name, crossing as a `.name`.
    public var propValue: PropValue { .name(name) }

    /// A kind back from its name - nil for any other kind of value.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .name(let name) = propValue else { return nil }

        self.init(name)
    }

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
