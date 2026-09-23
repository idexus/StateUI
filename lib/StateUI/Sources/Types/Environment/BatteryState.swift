// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How the battery is doing.
public enum BatteryState: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// Plugged in and charging.
    case charging = 1

    /// Running on the battery.
    case discharging = 2

    /// Plugged in and full.
    case full = 3

    /// Plugged in and not charging, such as while held at a charge limit.
    case notCharging = 4

    /// There is no battery in this machine.
    case notPresent = 5
}
