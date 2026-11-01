// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The structure every host shows: an application, its scenes, their windows, and the view each window shows.
// Design: docs/design/views/pages.md#application-scene-window-page

/// The application at the root of a StateUI tree.
///
/// Named to the host once, at startup, with `register()`; the host then
/// connects the platform's application and scene lifecycle to it.
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
///         }
///
///         var body: some Scene {
///             WindowGroup { MainPage() }
///         }
///     }
///
/// Write it in `init`: the application is made at its first need, before the
/// first view is built. The standard environment - the device, the display, the
/// locale - is known there already.
@MainActor
public protocol Application {
    /// The scenes the application is made of.
    associatedtype Body: Scene

    /// Makes the application, at its first need - see `register()`.
    init()

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

extension Application {
    // Design: docs/design/views/pages.md#the-application-is-named-once
    /// Names the application to the host: every head calls it before its host runs.
    ///
    ///     NotesApp.register()
    ///
    /// The application is made at its first need - once the host has told what the device is - with a fresh
    /// application session, and kept for the life of the process, so `@State` declared on it outlives every window.
    public static func register() {
        Renderer.shared.setApplication(Self())
    }
}
