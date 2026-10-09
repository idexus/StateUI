// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The kind of machine the interface is showing on, as the host reports it
/// before the first render - so the first tree already knows. Read it as the
/// device's `info`:
///
///     @Environment(\.device) private var device
///
///     var body: some View {
///         device.info.formFactor == .desktop ? wideLayout : phoneLayout
///     }
///
/// The formFactor distinguishes form factors that share an operating system. A
/// headless host leaves values at their documented defaults.
@MainActor
public final class DeviceInfo {
    /// Phone, tablet, desktop, television, or watch.
    @State public internal(set) var formFactor: FormFactor = .unknown

    /// The host platform's name, such as "macOS", "iOS", "Android",
    /// "Windows", "Linux", or "Web" - text, since a host may name a platform
    /// this library does not know.
    @State public internal(set) var platform = ""

    /// The hardware model, where the platform shares it.
    @State public internal(set) var model = ""

    /// Who made the device, where the platform shares it.
    @State public internal(set) var manufacturer = ""

    /// The device's own name, where the platform shares it.
    @State public internal(set) var name = ""

    /// The operating system version as displayable text.
    @State public internal(set) var versionString = ""

    /// Real hardware or an emulator.
    @State public internal(set) var deviceType: DeviceType = .unknown

    /// A device as a test or a preview fakes it; what is not said starts as a headless host's does.
    public init(
        formFactor: FormFactor = .unknown, platform: String = "", model: String = "", manufacturer: String = "",
        name: String = "", versionString: String = "", deviceType: DeviceType = .unknown
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
