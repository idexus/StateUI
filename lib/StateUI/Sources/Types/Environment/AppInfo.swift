// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The application, as the host describes it - the manifest facts, and the
/// one value here that CHANGES: the theme. Resolve it with
/// `@Environment var app: AppInfo`.
public final class AppInfo {
    /// The application's display name.
    @State public var name = ""

    /// The bundle or package identifier, such as "com.example.gallery".
    @State public var packageName = ""

    /// The version people read, such as "1.0".
    @State public var versionString = ""

    /// The build number behind it.
    @State public var buildString = ""

    /// Light or dark, as the system asks, updated live when the user switches.
    /// A `Color(light:dark:)` follows the theme by itself; read this for logic
    /// that branches on the theme.
    @State public var requestedTheme: Theme = .system

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}
