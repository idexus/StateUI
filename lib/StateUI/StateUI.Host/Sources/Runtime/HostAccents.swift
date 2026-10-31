// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The accent in force, the same on every host: the application's where its platform took it, else the one the
/// platform reports - the user's, or its own where the user chooses none. The core hears it through `CoreLink`.
/// Design: docs/design/host/runtime.md#the-accent-in-force
@_spi(Host) @MainActor public enum HostAccents {
    /// The accent the platform reports, as the host last reported it.
    private(set) static var system = Color(hex: 0x0A84FF)

    /// The application's accent where its platform took it; nil while it keeps the platform's.
    public private(set) static var held: Color?

    /// The accent in force now.
    public static var current: Color { held ?? system }

    /// Takes the accent the host reports the platform drawing in; the accent in force now.
    static func report(system accent: Color) -> Color {
        system = accent
        return current
    }

    /// Takes the application's accent its platform took, nil for none; the accent in force now.
    static func hold(_ accent: Color?) -> Color {
        held = accent
        return current
    }
}
