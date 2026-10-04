// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The names of what the library offers every view's environment, each read with `@Environment` and its name:
///
///     @Environment(\.window) private var window
///
/// A view reads the nearest: the scene and the window it stands in, or a fake one branch was given with
/// `.environment(...)`.
public struct EnvironmentValues {
    /// Made by no one: a name is read through `@Environment`.
    private init() {}

    /// The application's session: its facts (`info`), its phase, its styles and motion, its scenes, and the opening
    /// of windows.
    public var application: ApplicationSession { StandardEnvironment.application }

    /// The session of the scene the view stands in.
    public var scene: SceneSession { StandardEnvironment.scene }

    /// The session of the window the view stands in.
    public var window: WindowSession { StandardEnvironment.window }

    /// The device the application runs on: its facts, display, battery and network.
    public var device: Device { StandardEnvironment.device }

    /// The user's language, region, time zone and conventions.
    public var locale: LocaleInfo { StandardEnvironment.locale }
}
