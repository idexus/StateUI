// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// The kind of device the interface is showing on.
///
///     @Environment var device: DeviceInfo
///     …
///     device.formFactor == .desktop ? wideLayout : phoneLayout
///
/// It tells a phone from a tablet where the platform alone cannot:
/// `stateUIPlatform()` is iOS on both. `\(formFactor)` prints the case name.
public enum FormFactor: Int32, Sendable {
    /// The host has not said - a headless test, or a platform that could not
    /// tell.
    case unknown = 0

    /// A phone.
    case phone = 1

    /// A tablet - an iPad, an Android tablet.
    case tablet = 2

    /// A desktop computer.
    case desktop = 3

    /// A television.
    case tv = 4

    /// A watch.
    case watch = 5
}
