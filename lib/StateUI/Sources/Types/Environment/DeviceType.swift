// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Whether this is real hardware.
public enum DeviceType: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// A physical device.
    case physical = 1

    /// An emulator or a simulator.
    case virtual = 2
}
