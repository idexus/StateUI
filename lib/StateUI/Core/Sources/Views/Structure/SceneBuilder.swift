// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A scene's body counted by type: one main window, and any number of windows beside it, in any order.
// Design: docs/design/views/pages.md#scenes

/// Builds a scene's `body`: its main window - a `WindowGroup` with no name - and the windows it opens beside it,
/// in any order, an `if` for a window only some scenes declare.
///
///     var body: some Scene {
///         WindowGroup { MainPage() }
///         Window(.inspector) { Inspector() }
///     }
@resultBuilder
public enum SceneBuilder {
    /// The main window, and the windows beside it so far.
    public struct Main {
        let main: DeclaredWindows
        var groups: [DeclaredWindows]
    }

    /// Windows beside the main one, before the main one is written.
    public struct Beside {
        var groups: [DeclaredWindows]
    }

    /// The main window.
    public static func buildExpression(_ main: WindowGroup<WindowRole.Main>) -> Main {
        Main(main: main.declared, groups: [])
    }

    /// Windows opened beside the main one, one per value.
    public static func buildExpression(_ group: WindowGroup<WindowRole.Beside>) -> Beside {
        Beside(groups: [group.declared])
    }

    /// One window opened beside the main one.
    public static func buildExpression(_ window: Window<WindowRole.Beside>) -> Beside {
        Beside(groups: [window.declared])
    }

    /// A view, refused here: it stands in a window.
    @available(*, unavailable, message: "a view stands in a window: WindowGroup { MainPage() }")
    public static func buildExpression<Shown: View>(_ view: Shown) -> Main { fatalError() }

    /// A scene, refused here: it stands in the application's body.
    @available(*, unavailable, message: "a scene's body holds its windows; a scene stands in the application's body")
    public static func buildExpression<Other: Scene>(_ scene: Other) -> Main { fatalError() }

    /// The first window written.
    public static func buildPartialBlock(first: Main) -> Main { first }

    /// The first window written, beside the main one.
    public static func buildPartialBlock(first: Beside) -> Beside { first }

    /// A window beside the main one, after it.
    public static func buildPartialBlock(accumulated: Main, next: Beside) -> Main {
        Main(main: accumulated.main, groups: accumulated.groups + next.groups)
    }

    /// The main window, after windows beside it.
    public static func buildPartialBlock(accumulated: Beside, next: Main) -> Main {
        Main(main: next.main, groups: accumulated.groups + next.groups)
    }

    /// A window beside the main one, after another.
    public static func buildPartialBlock(accumulated: Beside, next: Beside) -> Beside {
        Beside(groups: accumulated.groups + next.groups)
    }

    /// A second main window, refused: a scene has one.
    @available(*, unavailable, message: "a scene has one main window: give the other a name, Window(.kind)")
    public static func buildPartialBlock(accumulated: Main, next: Main) -> Main { fatalError() }

    /// A window only some scenes declare.
    public static func buildOptional(_ beside: Beside?) -> Beside { beside ?? Beside(groups: []) }

    /// The `if` branch of an if/else of windows beside the main one.
    public static func buildEither(first: Beside) -> Beside { first }

    /// The `else` branch.
    public static func buildEither(second: Beside) -> Beside { second }

    /// A main window under an `if`, refused: it is always there.
    @available(*, unavailable, message: "the main window is always there: choose what it shows inside its view")
    public static func buildOptional(_ main: Main?) -> Beside { fatalError() }

    /// The scene's windows.
    public static func buildFinalResult(_ scene: Main) -> Windows {
        Windows(main: scene.main, groups: scene.groups)
    }

    /// Windows with no main one, refused: a scene needs it.
    @available(*, unavailable, message: "a scene needs its main window: WindowGroup { MainPage() }")
    public static func buildFinalResult(_ beside: Beside) -> Windows { fatalError() }
}
