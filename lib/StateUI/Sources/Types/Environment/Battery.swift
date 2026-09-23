// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The battery, as the host last reported it. Resolve it with
/// `@Environment var battery: Battery`; the values update as the platform
/// reports, and exactly the views that read them are rebuilt.
///
///     let fake = Battery()
///     fake.chargeLevel = 0.07
///     ChildView().environment(fake)
///
/// A host that cannot observe a battery leaves `chargeLevel` at `-1` and the
/// remaining values at `.unknown`. A test provides a fake, as above.
public final class Battery {
    /// How full the battery is, 0 to 1 - and -1 until the host has said,
    /// which a host without battery information may never do.
    @State public var chargeLevel: Double = -1

    /// Charging, discharging, full, or another settled battery state.
    @State public var state: BatteryState = .unknown

    /// Wall, USB, wireless, or the battery itself.
    @State public var powerSource: BatteryPowerSource = .unknown

    /// Whether the platform's battery saver is on - a good reason to animate
    /// less.
    @State public var energySaverStatus: EnergySaverStatus = .unknown

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}
