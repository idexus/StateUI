// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The application, as the host describes it - the manifest facts, and the
/// two values here that CHANGE: the theme and the accent. Read it as the
/// application's `info`: `@Environment(\.application) private var app`, then
/// `app.info.name`.
@MainActor
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
    @State public var colorScheme: ColorScheme = .system

    /// The accent the user chose for the system - where the platform has
    /// none, the application's own tint - updated live when the user changes
    /// it. A view reading it is built again as it changes.
    ///
    ///     Switch($on).tint(app.info.accentColor)
    @State public var accentColor = AppInfo.standardAccent

    /// The accent before the host says the system's.
    nonisolated static let standardAccent = Color("#0A84FF")

    /// A fresh instance, its values starting as a headless host's do.
    public init() {}
}
