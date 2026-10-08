// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The theme in force, the same on every host: the one the application holds, else the one the system asks for -
/// so a host whose toolkit tells it the system's alone reports the application's all the same. The core hears it
/// through `CoreLink`.
/// Design: docs/design/host/runtime.md#the-theme-in-force
@_spi(Host) @MainActor public enum HostThemes {
    /// The theme the system asks for, as the host last reported it.
    private(set) static var system = ColorScheme.light

    /// The theme the application holds - `.system` while it follows the system.
    public private(set) static var held = ColorScheme.system

    /// The theme in force now.
    public static var current: ColorScheme {
        inForce(held: held, system: system)
    }

    /// The theme in force where the application holds `held` and the system asks for `system`.
    public static func inForce(held: ColorScheme, system: ColorScheme) -> ColorScheme {
        held == .system ? system : held
    }

    /// Takes the theme the host reports the system asking for; the theme in force now.
    static func report(system theme: ColorScheme) -> ColorScheme {
        system = theme
        return inForce(held: held, system: system)
    }

    /// Takes the theme the application holds; the theme in force now.
    static func hold(_ theme: ColorScheme) -> ColorScheme {
        held = theme
        return inForce(held: held, system: system)
    }
}
