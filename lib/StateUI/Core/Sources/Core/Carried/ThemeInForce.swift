// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/state.md#themed-colors-on-a-carried-state

/// The theme a value is laid for the host in: the color scheme and the accent.
struct ThemeInForce: Sendable, Equatable {
    var scheme: ColorScheme
    var accent: Color

    /// The application's, as it stands - read without making anybody its reader.
    @MainActor static var current: ThemeInForce {
        StandardEnvironment.application.info.theme
    }

    /// Where none is handed: the light half, the application's first accent.
    static let standard = ThemeInForce(scheme: .light, accent: ApplicationInfo.standardAccent)
}

/// A value whose carried form follows the theme or accent.
protocol ThemeWearing {
    var wearsTheTheme: Bool { get }

    /// The value's lanes in `theme`.
    func carried(wearing theme: ThemeInForce) -> StateCarried
}

extension StateValue {
    /// The value's lanes in `theme`: its own, unless it turns with the theme.
    func carried(in theme: ThemeInForce) -> StateCarried {
        (self as? any ThemeWearing)?.carried(wearing: theme) ?? carried
    }
}
