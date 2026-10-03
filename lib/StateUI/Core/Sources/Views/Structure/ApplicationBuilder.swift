// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Builds an application's `body`: the one scene it is made of - a `Scene` of its own, or a `WindowGroup` when
/// its sessions need no state of their own.
///
///     var body: some Scene { WindowGroup { MainPage() } }
///     var body: some Scene { EditorScene().environment(library) }
@resultBuilder
public enum ApplicationBuilder {
    /// The application's scene.
    public struct One<Declared: Scene> {
        let scene: Declared
    }

    /// The scene.
    public static func buildExpression<Declared: Scene>(_ scene: Declared) -> One<Declared> { One(scene: scene) }

    /// A window beside the main one, refused here: it belongs to a `Scene`.
    @available(*, unavailable, message: "a window beside the main one belongs to a Scene: declare both in one")
    public static func buildExpression(_ window: Window<WindowRole.Beside>) -> One<Windows> { fatalError() }

    /// A window beside the main one, refused here: it belongs to a `Scene`.
    @available(*, unavailable, message: "a window beside the main one belongs to a Scene: declare both in one")
    public static func buildExpression(_ group: WindowGroup<WindowRole.Beside>) -> One<Windows> { fatalError() }

    /// A view, refused here: it stands in a window.
    @available(*, unavailable, message: "a view stands in a window: WindowGroup { MainPage() }")
    public static func buildExpression<Shown: View>(_ view: Shown) -> One<Windows> { fatalError() }

    /// The scene written.
    public static func buildBlock<Declared>(_ one: One<Declared>) -> One<Declared> { one }

    /// Several scenes, refused: an application is made of one.
    @available(*, unavailable, message: "an application's body holds one scene")
    public static func buildBlock<First, Second>(_ first: One<First>, _ second: One<Second>) -> One<First> {
        fatalError()
    }

    /// Several scenes, refused: an application is made of one.
    @available(*, unavailable, message: "an application's body holds one scene")
    public static func buildBlock<First, Second, Third>(
        _ first: One<First>, _ second: One<Second>, _ third: One<Third>
    ) -> One<First> {
        fatalError()
    }

    /// The scene, as the application's body.
    public static func buildFinalResult<Declared>(_ one: One<Declared>) -> Declared { one.scene }
}
