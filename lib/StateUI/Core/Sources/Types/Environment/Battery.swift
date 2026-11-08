// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The battery, as the host last reported it. Read it as the device's
/// `battery`, `@Environment(\.device)`; the values update as the platform
/// reports, and exactly the views that read them are rebuilt.
///
///     let fake = Device(battery: Battery(chargeLevel: 0.07))
///     ChildView().environment(fake)
///
/// A host that cannot observe a battery leaves `chargeLevel` nil and the
/// remaining values at `.unknown`. A test provides a fake, as above.
@MainActor
public final class Battery {
    /// How full the battery is, 0 to 1; nil until the host has said - which a
    /// host without battery information may never do - and where no battery
    /// stands.
    public internal(set) var chargeLevel: Double? {
        get { _chargeLevel }
        set { _chargeLevel = newValue }
    }

    @State private var _chargeLevel: Double?

    /// Charging, discharging, full, or another settled battery state.
    public internal(set) var state: BatteryState {
        get { _state }
        set { _state = newValue }
    }

    @State private var _state: BatteryState = .unknown

    /// Wall, USB, wireless, or the battery itself.
    public internal(set) var powerSource: BatteryPowerSource {
        get { _powerSource }
        set { _powerSource = newValue }
    }

    @State private var _powerSource: BatteryPowerSource = .unknown

    /// Whether the platform's battery saver is on - a good reason to animate
    /// less.
    public internal(set) var energySaverStatus: EnergySaverStatus {
        get { _energySaverStatus }
        set { _energySaverStatus = newValue }
    }

    @State private var _energySaverStatus: EnergySaverStatus = .unknown

    /// A battery as a test or a preview fakes it, for one branch with `.environment(...)`; what is not said starts
    /// as a headless host's does.
    public init(
        chargeLevel: Double? = nil, state: BatteryState = .unknown, powerSource: BatteryPowerSource = .unknown,
        energySaverStatus: EnergySaverStatus = .unknown
    ) {
        self.chargeLevel = chargeLevel
        self.state = state
        self.powerSource = powerSource
        self.energySaverStatus = energySaverStatus
    }
}
