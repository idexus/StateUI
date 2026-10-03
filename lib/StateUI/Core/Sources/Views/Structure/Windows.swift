// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A scene's windows as its `body` declares them: its main window, and the kinds it opens beside it. What
/// `SceneBuilder` makes of a scene's body; nobody writes one.
public struct Windows: Scene {
    /// The main window.
    let main: DeclaredWindows

    /// The kinds of window the scene may open beside its main one.
    let groups: [DeclaredWindows]

    /// None: the library's own scene.
    public var body: Never { return fatalError("Windows is the library's own scene: it has no body") }
}
