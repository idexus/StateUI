// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The structure every host shows: an application, its scenes, their windows, and the view each window shows.
// Design: docs/design/views/pages.md#application-scene-window-page

/// The application at the root of a StateUI tree.
///
/// Handed to `stateUIUseApp` once, at startup; the host then connects the
/// platform's application and scene lifecycle to it.
///
/// Its `body` is the scene it is made of, and nothing else. What the whole
/// application is - its styles, how its values move, what it keeps between
/// launches - is its `ApplicationSession`, written where the application is
/// made:
///
///     struct NotesApp: Application {
///         @Environment(\.application) private var application
///
///         init() {
///             application.styles = AppStyles.sheet
///             application.persistentKeys = [.lastNote]
///         }
///
///         var body: some Scene {
///             WindowGroup { MainPage() }
///         }
///     }
///
/// Write it in `init`: the application is made at its first need, before the
/// first view is built, and the kept state's keys are read from it. The standard
/// environment - the device, the display, the locale - is known there already.
@MainActor
public protocol Application {
    /// The scenes the application is made of.
    associatedtype Body: Scene

    /// The application's scenes, each standing at most once, with the
    /// windows it declares. See `Scene`.
    ///
    ///     var body: some Scene { WindowGroup { MainPage() } }  // one kind of window
    ///     var body: some Scene {
    ///         EditorScene().environment(library)            // the editors and their tools
    ///         Window(.about) { AboutPage() }                // a scene of its own
    ///     }
    ///
    /// *File ▸ New Window* makes one more window of the `WindowGroup` with no name.
    @ApplicationBuilder var body: Body { get }
}

// Design: docs/design/views/pages.md#the-application-is-named-once
/// Names the application to the host.
///
/// The one line an app writes outside its own interface, in a function of its
/// own module that every head calls by name before its host runs. The library
/// cannot declare that function, as the dependency runs app -> library:
///
///     @_cdecl("stateui_app_register")
///     public func stateui_app_register() {
///         stateUIUseApp(HelloWorldApp())
///     }
///
/// - Parameter application: the application, made at its first need - once
///   the host has told what the device is - with a fresh application session,
///   and kept for the life of the process, so `@State` declared on it
///   outlives every window.
@MainActor
public func stateUIUseApp<Declared: Application>(_ application: @escaping @autoclosure () -> Declared) {
    Renderer.shared.setApplication(application())
}
