// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/state.md#themed-colours-on-a-carried-state

/// The theme a value is laid for the host in: the colour scheme and the accent.
struct ThemeInForce: Sendable, Equatable {
    var scheme: ColorScheme
    var accent: Color

    /// The application's, as it stands - read without making anybody its reader.
    @MainActor static var current: ThemeInForce {
        let info = StandardEnvironment.application.info

        return ThemeInForce(scheme: info.$colorScheme.standing, accent: info.$accentColor.standing)
    }

    /// Where none is handed: the light half, the application's first accent.
    static let standard = ThemeInForce(scheme: .light, accent: AppInfo.standardAccent)
}

/// A value that turns with the theme or the accent: a colour pair, the accent,
/// what holds one.
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
