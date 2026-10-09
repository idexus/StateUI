// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The device the application runs on: what it is, its display, its battery and its network. A view reads the
/// one fact it shows, and builds again when that fact changes.
///
///     @Environment(\.device) private var device
///
///     Text(device.info.formFactor == .phone ? "Phone" : "Larger screen")
@MainActor
public final class Device {
    /// What the device is: its form factor, platform, model and name.
    public let info = DeviceInfo()

    /// Its display: its size, density, orientation and refresh rate.
    public let display = DeviceDisplay()

    /// Its battery: the charge, whether it charges, from what, and the energy saver.
    public let battery = Battery()

    /// Its network: whether there is access, and over what.
    public let connectivity = Connectivity()

    /// A fresh device, for providing a fake to one branch with `.environment(...)`. Its facts start as a headless
    /// host's do.
    public init() {}
}
