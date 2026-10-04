// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The one instance of what the library offers every view, read by name with `@Environment`, and the scope every
/// render starts from; written by the host's reports and read by builds, both on the UI thread.
/// Design: docs/design/types/environment.md#one-door-and-the-bottom-of-the-scope
enum StandardEnvironment {
    nonisolated(unsafe) static let device = Device()
    nonisolated(unsafe) static let locale = LocaleInfo()
    nonisolated(unsafe) static let application = ApplicationSession()

    // What a view outside every scene or window reads; each of those offers its own, nearer.
    nonisolated(unsafe) static let scene = SceneSession()
    nonisolated(unsafe) static let window = WindowSession()

    /// What every render starts its scope with, keyed as `.environment()` keys.
    nonisolated(unsafe) static let scope: [(key: ObjectIdentifier, object: AnyObject)] = [
        (key: ObjectIdentifier(Device.self), object: device),
        (key: ObjectIdentifier(LocaleInfo.self), object: locale),
        (key: ObjectIdentifier(ApplicationSession.self), object: application),
        (key: ObjectIdentifier(SceneSession.self), object: scene),
        (key: ObjectIdentifier(WindowSession.self), object: window),
    ]

    /// The name each is read by, `@Environment(\.window)` - `EnvironmentValues`' members.
    static let names: [ObjectIdentifier: String] = [
        ObjectIdentifier(Device.self): "device",
        ObjectIdentifier(LocaleInfo.self): "locale",
        ObjectIdentifier(ApplicationSession.self): "application",
        ObjectIdentifier(SceneSession.self): "scene",
        ObjectIdentifier(WindowSession.self): "window",
    ]

    /// What an unfilled `@Environment` slot answers - the application's, built outside any render.
    static func object(for key: ObjectIdentifier) -> AnyObject? {
        scope.last(where: { $0.key == key })?.object
    }
}
