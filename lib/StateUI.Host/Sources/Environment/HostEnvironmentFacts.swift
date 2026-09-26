// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a host reads of the machine it stands on, turned into what the core is told the same way on every host.
/// Design: docs/design/host/runtime.md#the-environment
extension HostLocaleInfo {
    /// The locale as eight words: its language, its region, its name, its time zone, "1" for a 24-hour clock, the
    /// first day of the week as a number from Sunday's 0, "1" for metric measures and "1" for a language written
    /// right to left; nil for any other count of words.
    public init?(words: [String]) {
        guard words.count == 8 else { return nil }
        self.init(
            language: words[0], region: words[1], name: words[2], timeZone: words[3], uses24HourClock: words[4] == "1",
            firstDayOfWeek: Weekday(rawValue: Int32(Double(words[5]) ?? 0)) ?? .sunday,
            isMetric: words[6] == "1", layoutDirection: words[7] == "1" ? .rightToLeft : .leftToRight)
    }
}

extension HostDeviceInfo {
    /// The device as five words - its model, its maker, its name, its system's version, and "1" for a virtual
    /// machine - on `platform`, in `formFactor`; nil for any other count of words.
    public init?(words: [String], formFactor: FormFactor, platform: String) {
        guard words.count == 5 else { return nil }
        self.init(
            formFactor: formFactor, platform: platform, model: words[0], manufacturer: words[1], name: words[2],
            versionString: words[3], deviceType: words[4] == "1" ? .virtual : .physical)
    }
}

extension HostConnectivityInfo {
    /// The network by `NetworkAccess`'s number and a set of bits for the connections in use: 1 Bluetooth, 2
    /// cellular, 4 Ethernet, 8 Wi-Fi.
    public init(access: Int32, connections bits: Int32) {
        let kinds: [(bit: Int32, profile: ConnectionProfile)] = [
            (1, .bluetooth), (2, .cellular), (4, .ethernet), (8, .wiFi),
        ]
        self.init(
            networkAccess: NetworkAccess(rawValue: access) ?? .unknown,
            connectionProfiles: kinds.filter { bits & $0.bit != 0 }.map(\.profile))
    }
}

extension HostBatteryInfo {
    /// A desktop's power: no battery - the machine on mains, as full as it gets - or one charged to `level`, 0 to
    /// 1: charging, else discharging off mains, else full where it says so and waiting on mains where not.
    public init(present: Bool, level: Double, charging: Bool, onMains: Bool, full: Bool, saving: Bool) {
        let saver: EnergySaverStatus = saving ? .on : .off
        guard present else {
            self.init(chargeLevel: 1, state: .notPresent, powerSource: .ac, energySaverStatus: saver)
            return
        }
        let state: BatteryState = charging ? .charging : !onMains ? .discharging : full ? .full : .notCharging
        self.init(
            chargeLevel: level.isFinite ? min(max(level, 0), 1) : 0, state: state,
            powerSource: onMains ? .ac : .battery, energySaverStatus: saver)
    }
}

extension HostDisplayInfo {
    /// A screen `width` by `height` pixels that turns with nothing: landscape where it is at least as wide as it is
    /// tall.
    public init(width: Double, height: Double, density: Double, refreshRate: Double) {
        self.init(
            width: width, height: height, density: density, orientation: width >= height ? .landscape : .portrait,
            rotation: .rotation0, refreshRate: refreshRate)
    }
}
