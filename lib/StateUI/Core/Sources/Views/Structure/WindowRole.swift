// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a window declared in a scene is - told by the initializer it was written with, so a scene's builder counts
/// its main windows by type.
public enum WindowRole {
    /// The scene's main window: `WindowGroup { MainPage() }`.
    public enum Main {}

    /// A kind of window the scene opens beside its main one: `Window(.inspector) { … }`.
    public enum Beside {}
}
