// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Builds a scene's `body`: the windows it declares, in any number and order, an `if` for a window only some
/// applications declare.
///
///     var body: some Scene {
///         WindowGroup { NotePage() }
///         Window(.inspector) { InspectorPage() }
///     }
@resultBuilder
@MainActor
public enum SceneBuilder {
    /// The windows declared so far.
    public struct Declared {
        var windows: [DeclaredWindows]
    }

    /// A group of windows.
    public static func buildExpression(_ group: WindowGroup) -> Declared { Declared(windows: [group.declared]) }

    /// One window of a kind.
    public static func buildExpression(_ window: Window) -> Declared { Declared(windows: [window.declared]) }

    /// A view, refused here: it stands in a window.
    @available(*, unavailable, message: "a view stands in a window: WindowGroup { NotePage() }")
    public static func buildExpression<Shown: View>(_ view: Shown) -> Declared { fatalError() }

    /// A scene, refused here: it stands in the application's body.
    @available(*, unavailable, message: "a scene's body holds its windows; a scene stands in the application's body")
    public static func buildExpression<Other: Scene>(_ scene: Other) -> Declared { fatalError() }

    /// The first window written.
    public static func buildPartialBlock(first: Declared) -> Declared { first }

    /// A window after those before it.
    public static func buildPartialBlock(accumulated: Declared, next: Declared) -> Declared {
        Declared(windows: accumulated.windows + next.windows)
    }

    /// A window only some applications declare.
    public static func buildOptional(_ declared: Declared?) -> Declared { declared ?? Declared(windows: []) }

    /// The `if` branch of an if/else of windows.
    public static func buildEither(first: Declared) -> Declared { first }

    /// The `else` branch.
    public static func buildEither(second: Declared) -> Declared { second }

    /// The scene's windows.
    public static func buildFinalResult(_ declared: Declared) -> Windows { Windows(declared: declared.windows) }
}
