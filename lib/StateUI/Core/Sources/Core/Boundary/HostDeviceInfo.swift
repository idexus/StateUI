// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Device facts supplied before a native host asks for its first render.
@_spi(Host) public struct HostDeviceInfo: Equatable, Sendable {
    /// The device class used by adaptive application code.
    public let formFactor: FormFactor

    /// The platform's stable public name.
    public let platform: String

    /// The hardware model, where the platform exposes it.
    public let model: String

    /// The hardware manufacturer.
    public let manufacturer: String

    /// The user-visible device name, where available.
    public let name: String

    /// The operating-system version.
    public let versionString: String

    /// Whether the application runs on hardware or a virtual device.
    public let deviceType: DeviceType

    /// A complete device report.
    public init(
        formFactor: FormFactor,
        platform: String,
        model: String,
        manufacturer: String,
        name: String,
        versionString: String,
        deviceType: DeviceType
    ) {
        self.formFactor = formFactor
        self.platform = platform
        self.model = model
        self.manufacturer = manufacturer
        self.name = name
        self.versionString = versionString
        self.deviceType = deviceType
    }
}
