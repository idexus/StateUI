// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Where the power is coming from.
public enum BatteryPowerSource: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// The battery itself.
    case battery = 1

    /// A charger in the wall.
    case ac = 2

    /// A USB port.
    case usb = 3

    /// A wireless pad.
    case wireless = 4
}
