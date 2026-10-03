// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Builds an application's `body`: its kinds of scene, the first opening at launch - a `Scene` of its own, a
/// `WindowGroup` when its sessions need no state of their own, a `Window` for a scene of one session.
///
///     var body: some Scene {
///         NotesScene()                          // the first, and what File ▸ New opens
///         WindowGroup(.editor) { EditorPage() } // opened by application.openWindow(.editor)
///         Window(.preferences) { Preferences() } // one for the whole application
///     }
@resultBuilder
public enum ApplicationBuilder {
    /// The kinds of scene written so far.
    public struct Kinds {
        var scenes: [any Scene]
    }

    /// A kind of scene.
    public static func buildExpression<Declared: Scene>(_ scene: Declared) -> Kinds { Kinds(scenes: [scene]) }

    /// Windows per value written in the application's body, which go no further: they belong to a `Scene`.
    public struct PerValue {}

    /// Windows per value - a type of their own, refused where they stand.
    public static func buildExpression(_ group: WindowGroup<WindowRole.Beside>) -> PerValue { PerValue() }

    /// A view, refused here: it stands in a window.
    @available(*, unavailable, message: "a view stands in a window: WindowGroup { MainPage() }")
    public static func buildExpression<Shown: View>(_ view: Shown) -> Kinds { fatalError() }

    /// The first kind written.
    public static func buildPartialBlock(first: Kinds) -> Kinds { first }

    /// Another kind, after those before it.
    public static func buildPartialBlock(accumulated: Kinds, next: Kinds) -> Kinds {
        Kinds(scenes: accumulated.scenes + next.scenes)
    }

    /// Windows per value first, refused: they belong to a `Scene`.
    @available(*, unavailable, message: "windows per value belong to a Scene: declare them beside its main window")
    public static func buildPartialBlock(first: PerValue) -> Kinds { fatalError() }

    /// Windows per value after a kind, refused: they belong to a `Scene`.
    @available(*, unavailable, message: "windows per value belong to a Scene: declare them beside its main window")
    public static func buildPartialBlock(accumulated: Kinds, next: PerValue) -> Kinds { fatalError() }

    /// The application's kinds of scene, as its body.
    public static func buildFinalResult(_ kinds: Kinds) -> SceneKinds { SceneKinds(scenes: kinds.scenes) }
}
