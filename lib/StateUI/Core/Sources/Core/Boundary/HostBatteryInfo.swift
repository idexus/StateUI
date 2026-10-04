// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Battery facts supplied by a native host, whenever the platform reports a change.
@_spi(Host) public struct HostBatteryInfo: Equatable, Sendable {
    /// How full the battery is, 0 to 1.
    public let chargeLevel: Double

    /// Charging, discharging, full, or another settled battery state.
    public let state: BatteryState

    /// What the device draws its power from.
    public let powerSource: BatteryPowerSource

    /// Whether the platform's battery saver is on.
    public let energySaverStatus: EnergySaverStatus

    /// A complete battery report.
    public init(
        chargeLevel: Double,
        state: BatteryState,
        powerSource: BatteryPowerSource,
        energySaverStatus: EnergySaverStatus
    ) {
        self.chargeLevel = chargeLevel
        self.state = state
        self.powerSource = powerSource
        self.energySaverStatus = energySaverStatus
    }
}
