// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// One way the device is connected.
public enum ConnectionProfile: Int32, Sendable {
    /// A kind this library has no name for.
    case unknown = 0

    /// Bluetooth.
    case bluetooth = 1

    /// A mobile data connection.
    case cellular = 2

    /// A wired network.
    case ethernet = 3

    /// Wi-Fi.
    case wiFi = 4
}
