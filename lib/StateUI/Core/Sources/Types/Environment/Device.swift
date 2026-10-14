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
    public let info: DeviceInfo

    /// Its display: its size, density, orientation and refresh rate.
    public let display: DeviceDisplay

    /// Its battery: the charge, whether it charges, from what, and the energy saver.
    public let battery: Battery

    /// Its network: whether there is access, and over what.
    public let connectivity: Connectivity

    /// A device as a test or a preview fakes it, for one branch with `.environment(...)`; what is not said starts as
    /// a headless host's does.
    ///
    ///     Device(connectivity: Connectivity(networkAccess: .none))
    public init(
        info: DeviceInfo = DeviceInfo(), display: DeviceDisplay = DeviceDisplay(), battery: Battery = Battery(),
        connectivity: Connectivity = Connectivity()
    ) {
        self.info = info
        self.display = display
        self.battery = battery
        self.connectivity = connectivity
    }
}

extension Device {
    /// Whether the platform the application runs on honours `member` - its host realizes it. Where it does not,
    /// writing the member changes nothing, so a view may leave out what asks for it; the platform contract says why.
    ///
    ///     if device.honours(PickerContract.isOpen) {
    ///         Button("Open the list").onClicked { showing = true }
    ///     }
    public func honours<Owner: Contract, Value>(_ member: ElementProperty<Owner, Value>) -> Bool {
        HostRealizations.honours(member.name, of: Owner.name)
    }

    /// Whether the platform the application runs on raises `event` - its host realizes it.
    public func honours<Owner: Contract, Payload>(_ event: ElementEvent<Owner, Payload>) -> Bool {
        HostRealizations.honours(event.name, of: Owner.name)
    }
}

