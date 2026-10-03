// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which of the application's kinds of scene a scene is - named by its main window.
/// Design: docs/design/core/scenes.md#kinds-of-scene
enum SceneKind: Hashable {
    /// The application's first kind: what the scene waiting for the platform's first window is.
    case first

    /// The kind whose main window has no name: what *File ▸ New* opens.
    case unnamed

    /// The kind whose main window is of this type.
    case named(WindowType)

    /// The kind whose main window is of `type`, nil for none.
    init(main type: WindowType?) {
        self = type.map(SceneKind.named) ?? .unnamed
    }
}
