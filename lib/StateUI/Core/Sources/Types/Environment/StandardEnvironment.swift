// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the host knows, as objects of `@State` properties every view resolves with `@Environment`.
// Design: docs/design/types/environment.md#the-standard-environment

/// The one instance of each standard provider and the scope every render starts from.
/// Design: docs/design/types/environment.md#one-door-and-the-bottom-of-the-scope
enum StandardEnvironment {
    // Written by the host's reports and read by builds, both on the UI thread.
    nonisolated(unsafe) static let battery = Battery()
    nonisolated(unsafe) static let connectivity = Connectivity()
    nonisolated(unsafe) static let display = DeviceDisplay()
    nonisolated(unsafe) static let locale = LocaleInfo()
    nonisolated(unsafe) static let device = DeviceInfo()
    nonisolated(unsafe) static let app = AppInfo()

    /// The application's session: one per process, its phase pushed by the host.
    nonisolated(unsafe) static let application = ApplicationSession()

    // What a view outside every scene, window or page reads; each of those offers its own, nearer.
    nonisolated(unsafe) static let scene = SceneSession()
    nonisolated(unsafe) static let window = WindowSession()
    nonisolated(unsafe) static let page = PageSession()

    /// What every render starts its scope with, keyed as `.environment()` keys.
    nonisolated(unsafe) static let scope: [(key: ObjectIdentifier, object: AnyObject)] = [
        (key: ObjectIdentifier(Battery.self), object: battery),
        (key: ObjectIdentifier(Connectivity.self), object: connectivity),
        (key: ObjectIdentifier(DeviceDisplay.self), object: display),
        (key: ObjectIdentifier(LocaleInfo.self), object: locale),
        (key: ObjectIdentifier(DeviceInfo.self), object: device),
        (key: ObjectIdentifier(AppInfo.self), object: app),
        (key: ObjectIdentifier(ApplicationSession.self), object: application),
        (key: ObjectIdentifier(SceneSession.self), object: scene),
        (key: ObjectIdentifier(WindowSession.self), object: window),
        (key: ObjectIdentifier(PageSession.self), object: page),
    ]

    /// The standard provider of a type: what an unfilled `@Environment` slot answers,
    /// such as the application's, built outside any render.
    static func object(for key: ObjectIdentifier) -> AnyObject? {
        scope.last(where: { $0.key == key })?.object
    }
}
