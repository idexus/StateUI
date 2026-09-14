// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The kind of device an interface is showing on.
//
// The `DeviceInfo` PROVIDER - the class an interface resolves with
// `@Environment var device: DeviceInfo` - is in Types/HostEnvironment.swift
// with the other standard providers. This file holds the idiom's own type.

/// The kind of device the interface is showing on.
///
///     @Environment var device: DeviceInfo
///     …
///     device.idiom == .desktop ? wideLayout : phoneLayout
///
/// What separates a phone from a desktop where the PLATFORM cannot: iOS is a
/// phone and a tablet, macOS and Windows are desktops, and
/// `stateUIPlatform()` - compiled in - can never tell the first two apart.
///
/// The numbers are this library's own - both sides of the wire agree on them -
/// and `\(idiom)` prints the case name for a footer that wants the word.
public enum DeviceIdiom: Int32, Sendable {
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
