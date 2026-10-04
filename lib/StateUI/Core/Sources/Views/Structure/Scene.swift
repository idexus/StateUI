// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How an application is laid out in windows.
// Design: docs/design/views/pages.md#scenes

/// One of the application's scenes: the windows it declares and the state they share. It stands at most once,
/// opening with its first window and ending with its last.
///
///     struct NotesScene: Scene {
///         @State private var library = Library()
///
///         var body: some Scene {
///             WindowGroup { NotePage() }
///                 .environment(library)
///             Window(.inspector) { Inspector() }
///                 .environment(library)
///         }
///     }
///
/// Every window of a scene shares its `@State`; what belongs to one window is the `@State` of the view it shows.
/// An application with nothing to share writes its windows in its own `body`, each a scene of its own:
/// `var body: some Scene { WindowGroup { NotePage() } }`. What every scene shares belongs to the `Application`
/// and reaches a scene through `.environment(_:)`. The application's session opens a scene's windows.
public protocol Scene {
    /// The scene it is made of.
    associatedtype Body: Scene

    /// The scene's windows. Read again when a state it read changes.
    @SceneBuilder var body: Body { get }
}

/// The body of the library's own scenes, which have none.
extension Never: Scene {}

extension Scene {
    /// Offers an object to every window of this scene, resolved by type the way `.environment` on a view is.
    ///
    ///     var body: some Scene { GalleryScene().environment(library) }
    ///
    /// A nearer `.environment()` of the same type - on a window, or on a view inside - overrides it for its own
    /// branch.
    public func environment<Value: AnyObject>(_ object: Value) -> some Scene {
        OfferingScene(base: self, key: ObjectIdentifier(Value.self), object: object)
    }

    /// The windows this scene declares: its body followed down to the library's own scene.
    var declaredWindows: Windows {
        if let windows = self as? Windows { return windows }
        if let group = self as? WindowGroup { return Windows(declared: [group.declared]) }
        if let window = self as? Window { return Windows(declared: [window.declared]) }
        if let offering = self as? any Offering { return offering.offered.declaredWindows }

        return body.declaredWindows
    }
}

/// A scene with an object offered to everything in it.
protocol Offering {
    /// The scene the object is offered to.
    var offered: any Scene { get }

    /// The type the object answers for.
    var key: ObjectIdentifier { get }

    /// The object.
    var object: AnyObject { get }
}

/// A scene with an object offered to everything in it.
struct OfferingScene<Base: Scene>: Scene, Offering {
    let base: Base
    let key: ObjectIdentifier
    let object: AnyObject

    var offered: any Scene { base }

    var body: Never { return fatalError("an offering is the library's own scene: it has no body") }
}
