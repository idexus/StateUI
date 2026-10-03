// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How an application is laid out in windows.
// Design: docs/design/views/pages.md#scenes

/// One session of the application: its main window, the windows it opens beside it, and the state they share.
///
///     struct EditorScene: Scene {
///         @State private var document = Document()
///
///         var body: some Scene {
///             WindowGroup { EditorPage() }
///                 .environment(document)
///             Window(.fonts) { FontsPanel() }
///                 .environment(document)
///         }
///     }
///
/// An application with nothing to keep per session writes its `WindowGroup` in its own `body` instead:
/// `var body: some Scene { WindowGroup { MainPage() } }`.
///
/// A scene holds `@State` once per session: a second *File ▸ New Window* is a second instance with state of its
/// own. What every session shares belongs to the `Application` and reaches a scene through `.environment(_:)`.
/// Opening and closing its windows is its `SceneSession`'s, in the environment of every view in it.
public protocol Scene {
    /// The scene it is made of.
    associatedtype Body: Scene

    /// The scene's windows: its main one, and the windows it may open beside it. Read again when a state it read
    /// changes.
    @SceneBuilder var body: Body { get }
}

/// The body of the library's own scenes, which have none.
extension Never: Scene {}

extension Scene {
    /// Offers an object to every window of every session of this scene, resolved by type the way `.environment`
    /// on a view is.
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
        if let main = self as? WindowGroup<WindowRole.Main> { return Windows(main: main.declared, groups: []) }
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
