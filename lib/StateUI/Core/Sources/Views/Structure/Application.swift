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
///         @Environment private var application: ApplicationSession
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
/// Write it in `init`: the kept state's keys are read as the application
/// registers, before the first view is built. The standard environment - the
/// device, the display, the locale - is known there already.
public protocol Application {
    /// The scene the application is made of.
    associatedtype Body: Scene

    /// What each session of the application is: its main window, the windows
    /// it opens beside it, and the state they share. See `Scene`.
    ///
    ///     var body: some Scene { WindowGroup { MainPage() } }         // one window
    ///     var body: some Scene { EditorScene().environment(library) }  // an editor's sessions
    ///
    /// The platform makes as many sessions as the user asks for.
    @ApplicationBuilder var body: Body { get }
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
/// - Parameter application: the application, made at its first need - once
///   the host has told what the device is - with a fresh application session,
///   and kept for the life of the process, so `@State` declared on it
///   outlives every window.
public func stateUIUseApp<Declared: Application>(_ application: @escaping @autoclosure () -> Declared) {
    Renderer.shared.setApplication(application())
}
