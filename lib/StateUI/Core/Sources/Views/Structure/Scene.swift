// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How an application is laid out in windows.
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
