// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A scene's body counted by type: one main window - its WindowGroup, else its first Window - and any number of
// windows beside it, in any order.
// Design: docs/design/views/pages.md#scenes

/// Builds a scene's `body`: its main window and the windows it opens beside it, in any order, an `if` for a window
/// only some scenes declare. The main window is its `WindowGroup` - with no name, or naming the scene's kind -
/// and, where it has none, its first `Window`, which makes a scene of one session.
///
///     var body: some Scene {
///         WindowGroup { MainPage() }
///         Window(.inspector) { Inspector() }
///     }
@resultBuilder
public enum SceneBuilder {
    /// The main window, a `WindowGroup`, and the windows beside it so far.
    public struct Main {
        let main: DeclaredWindows
        var groups: [DeclaredWindows]
    }

    /// A `Window` written before any `WindowGroup` - the main window of a scene of one session unless one comes -
    /// and the windows beside it so far.
    public struct Single {
        let main: DeclaredWindows
        var groups: [DeclaredWindows]
    }

    /// Windows of a kind per value, before any main window is written.
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

    /// One window of a kind: beside the main one, or the main one of a scene of one session.
    public static func buildExpression(_ window: Window<WindowRole.Beside>) -> Single {
        Single(main: window.declared, groups: [])
    }

    /// A view, refused here: it stands in a window.
    @available(*, unavailable, message: "a view stands in a window: WindowGroup { MainPage() }")
    public static func buildExpression<Shown: View>(_ view: Shown) -> Main { fatalError() }

    /// A scene, refused here: it stands in the application's body.
    @available(*, unavailable, message: "a scene's body holds its windows; a scene stands in the application's body")
    public static func buildExpression<Other: Scene>(_ scene: Other) -> Main { fatalError() }

    /// The first window written.
    public static func buildPartialBlock(first: Main) -> Main { first }

    /// The first window written, a `Window`.
    public static func buildPartialBlock(first: Single) -> Single { first }

    /// The first window written, one of a kind per value.
    public static func buildPartialBlock(first: Beside) -> Beside { first }

    /// A `Window` after the main one: beside it.
    public static func buildPartialBlock(accumulated: Main, next: Single) -> Main {
        Main(main: accumulated.main, groups: accumulated.groups + [next.main] + next.groups)
    }

    /// Windows per value after the main one.
    public static func buildPartialBlock(accumulated: Main, next: Beside) -> Main {
        Main(main: accumulated.main, groups: accumulated.groups + next.groups)
    }

    /// The main window after a `Window`, which stands beside it.
    public static func buildPartialBlock(accumulated: Single, next: Main) -> Main {
        Main(main: next.main, groups: [accumulated.main] + accumulated.groups + next.groups)
    }

    /// Another `Window` after the first: beside it.
    public static func buildPartialBlock(accumulated: Single, next: Single) -> Single {
        Single(main: accumulated.main, groups: accumulated.groups + [next.main] + next.groups)
    }

    /// Windows per value after a `Window`.
    public static func buildPartialBlock(accumulated: Single, next: Beside) -> Single {
        Single(main: accumulated.main, groups: accumulated.groups + next.groups)
    }

    /// The main window after windows per value.
    public static func buildPartialBlock(accumulated: Beside, next: Main) -> Main {
        Main(main: next.main, groups: accumulated.groups + next.groups)
    }

    /// The first `Window` after windows per value.
    public static func buildPartialBlock(accumulated: Beside, next: Single) -> Single {
        Single(main: next.main, groups: accumulated.groups + next.groups)
    }

    /// Windows per value after others.
    public static func buildPartialBlock(accumulated: Beside, next: Beside) -> Beside {
        Beside(groups: accumulated.groups + next.groups)
    }

    /// A second main window, refused: a scene has one.
    @available(*, unavailable, message: "a scene has one main window; one window of a kind beside it is a Window(.kind)")
    public static func buildPartialBlock(accumulated: Main, next: Main) -> Main { fatalError() }

    /// A window only some scenes declare: beside the main one.
    public static func buildOptional(_ beside: Beside?) -> Beside { beside ?? Beside(groups: []) }

    /// A `Window` only some scenes declare: beside the main one, never the main one.
    public static func buildOptional(_ window: Single?) -> Beside {
        Beside(groups: window.map { [$0.main] + $0.groups } ?? [])
    }

    /// The `if` branch of an if/else of windows beside the main one.
    public static func buildEither(first: Beside) -> Beside { first }

    /// The `else` branch.
    public static func buildEither(second: Beside) -> Beside { second }

    /// The `if` branch, a `Window`: beside the main one.
    public static func buildEither(first: Single) -> Beside { Beside(groups: [first.main] + first.groups) }

    /// The `else` branch, a `Window`: beside the main one.
    public static func buildEither(second: Single) -> Beside { Beside(groups: [second.main] + second.groups) }

    /// A main window under an `if`, refused: it is always there.
    @available(*, unavailable, message: "the main window is always there: choose what it shows inside its view")
    public static func buildOptional(_ main: Main?) -> Beside { fatalError() }

    /// The scene's windows, its main one a `WindowGroup`.
    public static func buildFinalResult(_ scene: Main) -> Windows {
        Windows(main: scene.main, groups: scene.groups)
    }

    /// The windows of a scene of one session, its main one its first `Window`.
    public static func buildFinalResult(_ scene: Single) -> Windows {
        Windows(main: scene.main, groups: scene.groups, oneSession: true)
    }

    /// Windows per value alone, refused: a scene needs its main window.
    @available(*, unavailable, message: "a scene needs its main window: WindowGroup { MainPage() }")
    public static func buildFinalResult(_ beside: Beside) -> Windows { fatalError() }
}
