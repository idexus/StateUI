// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The application, as the host describes it - the manifest facts, and the
/// two values here that CHANGE: the theme and the accent. Read it as the
/// application's `info`: `@Environment(\.application) private var app`, then
/// `app.info.name`.
@MainActor
public final class ApplicationInfo {
    /// The application's display name.
    public internal(set) var name: String {
        get { _name }
        set { _name = newValue }
    }

    @State private var _name = ""

    /// The bundle or package identifier, such as "com.example.gallery".
    public internal(set) var packageName: String {
        get { _packageName }
        set { _packageName = newValue }
    }

    @State private var _packageName = ""

    /// The version people read, such as "1.0".
    public internal(set) var version: String {
        get { _version }
        set { _version = newValue }
    }

    @State private var _version = ""

    /// The build number behind it.
    public internal(set) var build: String {
        get { _build }
        set { _build = newValue }
    }

    @State private var _build = ""

    /// The StateUI release the application runs on, as its tag names it - compiled in, never from a host.
    public let libraryVersion = "0.8.2"

    /// The theme in force - the one `application.colorScheme` holds, else the
    /// one the system asks for - updated live. A `Color(light:dark:)` follows
    /// the theme by itself; read this for logic that branches on the theme.
    public internal(set) var colorScheme: ColorScheme {
        get { _colorScheme }
        set { _colorScheme = newValue }
    }

    @State private var _colorScheme: ColorScheme = .light

    /// The accent the user chose for the system - where the platform has
    /// none, the application's own (`application.accentColor`), else the
    /// platform's - updated live as it changes. A view reading it is built
    /// again as it changes.
    ///
    ///     Switch($on).tint(app.info.accentColor)
    public internal(set) var accentColor: Color {
        get { _accentColor }
        set { _accentColor = newValue }
    }

    @State private var _accentColor = ApplicationInfo.standardAccent

    /// The theme as it stands, without subscribing the caller to either fact.
    var theme: ThemeInForce {
        ThemeInForce(scheme: $_colorScheme.standing, accent: $_accentColor.standing)
    }

    /// The accent before the host says the system's.
    nonisolated static let standardAccent = Color(hex: 0x0A84FF)

    /// An application as a test or a preview fakes it; what is not said starts as a headless host's does.
    public init(
        name: String = "", packageName: String = "", version: String = "", build: String = "",
        colorScheme: ColorScheme = .light, accentColor: Color? = nil
    ) {
        self.name = name
        self.packageName = packageName
        self.version = version
        self.build = build
        self.colorScheme = colorScheme
        self.accentColor = accentColor ?? ApplicationInfo.standardAccent
    }
}
