// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Builds an application's `body`: its scenes - a `Scene` of its own, or a window, which is a scene of its own with
/// no state - each standing once, while a window of it is open.
///
///     var body: some Scene {
///         NotesScene()                            // notes and their inspector, sharing the library
///         Window(.preferences) { Preferences() }  // one for the whole application
///     }
@resultBuilder
@MainActor
public enum ApplicationBuilder {
    /// The scenes written so far.
    public struct Declared {
        var scenes: [any Scene]
    }

    /// A scene.
    public static func buildExpression<Declared: Scene>(_ scene: Declared) -> Self.Declared {
        Self.Declared(scenes: [scene])
    }

    /// A view, refused here: it stands in a window.
    @available(*, unavailable, message: "a view stands in a window: WindowGroup { NotePage() }")
    public static func buildExpression<Shown: View>(_ view: Shown) -> Declared { fatalError() }

    /// The first scene written.
    public static func buildPartialBlock(first: Declared) -> Declared { first }

    /// A scene after those before it.
    public static func buildPartialBlock(accumulated: Declared, next: Declared) -> Declared {
        Declared(scenes: accumulated.scenes + next.scenes)
    }

    /// The application's scenes, as its body.
    public static func buildFinalResult(_ declared: Declared) -> Scenes { Scenes(declared: declared.scenes) }
}
