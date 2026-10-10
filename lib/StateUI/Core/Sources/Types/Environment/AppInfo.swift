// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The application, as the host describes it - the manifest facts, and the
/// two values here that CHANGE: the theme and the accent. Read it as the
/// application's `info`: `@Environment(\.application) private var app`, then
/// `app.info.name`.
@MainActor
public final class AppInfo {
    /// The application's display name.
    @State public internal(set) var name = ""

    /// The bundle or package identifier, such as "com.example.gallery".
    @State public internal(set) var packageName = ""

    /// The version people read, such as "1.0".
    @State public internal(set) var versionString = ""

    /// The build number behind it.
    @State public internal(set) var buildString = ""

    /// The theme in force - the one `application.colorScheme` holds, else the
    /// one the system asks for - updated live. A `Color(light:dark:)` follows
    /// the theme by itself; read this for logic that branches on the theme.
    @State public internal(set) var colorScheme: ColorScheme = .system

    /// The accent the user chose for the system - where the platform has
    /// none, the application's own tint - updated live when the user changes
    /// it. A view reading it is built again as it changes.
    ///
    ///     Switch($on).tint(app.info.accentColor)
    @State public internal(set) var accentColor = AppInfo.standardAccent

    /// The accent before the host says the system's.
    nonisolated static let standardAccent = Color("#0A84FF")

    /// An application as a test or a preview fakes it; what is not said starts as a headless host's does.
    public init(
        name: String = "", packageName: String = "", versionString: String = "", buildString: String = "",
        colorScheme: ColorScheme = .system, accentColor: Color? = nil
    ) {
        self.name = name
        self.packageName = packageName
        self.versionString = versionString
        self.buildString = buildString
        self.colorScheme = colorScheme
        self.accentColor = accentColor ?? AppInfo.standardAccent
    }
}
