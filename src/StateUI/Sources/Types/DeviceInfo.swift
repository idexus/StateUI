// MAUI: DeviceIdiom - Microsoft.Maui.Devices.
//
// The `DeviceInfo` PROVIDER - the class an interface resolves with
// `@Environment var device: DeviceInfo` - is in Types/HostEnvironment.swift
// with the other standard providers. This file holds the idiom's own type.

/// The kind of device the interface is showing on. MAUI: DeviceIdiom.
///
///     @Environment var device: DeviceInfo
///     …
///     device.idiom == .desktop ? wideLayout : phoneLayout
///
/// What separates a phone from a desktop where the PLATFORM cannot: iOS is a
/// phone and a tablet, Mac Catalyst and Windows are desktops, and
/// `stateUIPlatform()` - compiled in - can never tell the first two apart.
///
/// MAUI keeps this as a struct compared by value, with no number of its own,
/// so the numbers here are this library's - both sides of the wire agree, and
/// `\(idiom)` prints the case name for a footer that wants the word.
public enum DeviceIdiom: Int32, Sendable {
    /// The host has not said - a headless test, or a platform that could not
    /// tell. MAUI: DeviceIdiom.Unknown.
    case unknown = 0

    /// A phone. MAUI: DeviceIdiom.Phone.
    case phone = 1

    /// A tablet - an iPad, an Android tablet. MAUI: DeviceIdiom.Tablet.
    case tablet = 2

    /// A desktop - Mac Catalyst and Windows. MAUI: DeviceIdiom.Desktop.
    case desktop = 3

    /// A television. MAUI: DeviceIdiom.TV.
    case tv = 4

    /// A watch. MAUI: DeviceIdiom.Watch.
    case watch = 5
}
