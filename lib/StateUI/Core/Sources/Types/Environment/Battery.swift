// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The battery, as the host last reported it. Read it as the device's
/// `battery`, `@Environment(\.device)`; the values update as the platform
/// reports, and exactly the views that read them are rebuilt.
///
///     let fake = Device()
///     fake.battery.chargeLevel = 0.07
///     ChildView().environment(fake)
///
/// A host that cannot observe a battery leaves `chargeLevel` at `-1` and the
/// remaining values at `.unknown`. A test provides a fake, as above.
@MainActor
public final class Battery {
    /// How full the battery is, 0 to 1 - and -1 until the host has said,
    /// which a host without battery information may never do.
    @State public internal(set) var chargeLevel: Double = -1

    /// Charging, discharging, full, or another settled battery state.
    @State public internal(set) var state: BatteryState = .unknown

    /// Wall, USB, wireless, or the battery itself.
    @State public internal(set) var powerSource: BatteryPowerSource = .unknown

    /// Whether the platform's battery saver is on - a good reason to animate
    /// less.
    @State public internal(set) var energySaverStatus: EnergySaverStatus = .unknown

    /// A battery as a test or a preview fakes it, for one branch with `.environment(...)`; what is not said starts
    /// as a headless host's does.
    public init(
        chargeLevel: Double = -1, state: BatteryState = .unknown, powerSource: BatteryPowerSource = .unknown,
        energySaverStatus: EnergySaverStatus = .unknown
    ) {
        self.chargeLevel = chargeLevel
        self.state = state
        self.powerSource = powerSource
        self.energySaverStatus = energySaverStatus
    }
}
