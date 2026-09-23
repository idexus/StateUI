// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The kind of machine the interface is showing on, as the host reports it
/// before the first render - so the first tree already knows. Resolve it with
/// `@Environment var device: DeviceInfo`:
///
///     @Environment var device: DeviceInfo
///
///     var content: any View {
///         device.formFactor == .desktop ? wideLayout : phoneLayout
///     }
///
/// The formFactor distinguishes form factors that share an operating system. A
/// headless host leaves values at their documented defaults.
public final class DeviceInfo {
    /// Phone, tablet, desktop, television, or watch.
    @State public var formFactor: FormFactor = .unknown

    /// The host platform's name, such as "macOS", "iOS", "Android",
    /// "Windows", "Linux", or "Web" - text, since a host may name a platform
    /// this library does not know.
    @State public var platform = ""

    /// The hardware model, where the platform shares it.
    @State public var model = ""

    /// Who made the device, where the platform shares it.
    @State public var manufacturer = ""

    /// The device's own name, where the platform shares it.
    @State public var name = ""

    /// The operating system version as displayable text.
    @State public var versionString = ""

    /// Real hardware or an emulator.
    @State public var deviceType: DeviceType = .unknown

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}
