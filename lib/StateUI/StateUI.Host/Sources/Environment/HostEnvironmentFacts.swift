// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a host reads of the machine it stands on, turned into what the core is told the same way on every host.
/// Design: docs/design/host/runtime.md#the-environment
extension HostLocaleInfo {
    /// The locale as six words - its full language tag, its time zone, "1" for a 24-hour clock, the
    /// first day of the week as a number from Sunday's 0, "1" for metric measures and "1" for a language written
    /// right to left - and then the user's languages as tags, most wanted first; nil for fewer words.
    /// Empty tag, zone and language fields are unavailable; nonempty invalid tags remain values.
    public init?(words: [String]) {
        guard words.count >= 6 else { return nil }
        let day = Double(words[3]).flatMap { Int32(exactly: $0.rounded(.towardZero)) } ?? 0
        self.init(
            language: words[0].isEmpty ? nil : LocaleTag(words[0]),
            timeZone: words[1].isEmpty ? nil : TimeZoneName(words[1]), uses24HourClock: words[2] == "1",
            firstDayOfWeek: Weekday(rawValue: day) ?? .sunday,
            isMetric: words[4] == "1", writingDirection: words[5] == "1" ? .rightToLeft : .leftToRight,
            languages: words.dropFirst(6).filter { !$0.isEmpty }.map { LocaleTag($0) })
    }
}

@_spi(Host) extension FormFactor {
    /// A touch screen by its smallest width in points: a tablet from 600, a phone below.
    public static func touchScreen(smallestWidth: Double) -> FormFactor {
        smallestWidth >= 600 ? .tablet : .phone
    }
}

extension HostDeviceInfo {
    /// The device as five words - its model, its maker, its name, its system's version, and "1" for a virtual
    /// machine - on `platform`, in `formFactor`; nil for any other count of words.
    public init?(words: [String], formFactor: FormFactor, platform: String) {
        guard words.count == 5 else { return nil }
        self.init(
            formFactor: formFactor, platform: platform, model: words[0], manufacturer: words[1], name: words[2],
            platformVersion: words[3], isVirtual: words[4] == "1")
    }
}

extension HostConnectivityInfo {
    /// The network by `NetworkAccess`'s number and a set of bits for the connections in use: 1 Bluetooth, 2
    /// cellular, 4 Ethernet, 8 Wi-Fi.
    public init(access: Int32, connections bits: Int32) {
        let kinds: [(bit: Int32, profile: ConnectionProfile)] = [
            (1, .bluetooth), (2, .cellular), (4, .ethernet), (8, .wifi),
        ]
        self.init(
            networkAccess: NetworkAccess(rawValue: access) ?? .unknown,
            connectionProfiles: kinds.filter { bits & $0.bit != 0 }.map(\.profile))
    }
}

extension HostBatteryInfo {
    /// A desktop's power: no battery - the machine on mains, no charge to tell - or one charged to `level`, 0 to 1:
    /// charging, else discharging off mains, else full where it says so and waiting on mains where not.
    public init(present: Bool, level: Double, charging: Bool, onMains: Bool, full: Bool, saving: Bool) {
        let saver: EnergySaverStatus = saving ? .on : .off
        guard present else {
            self.init(chargeLevel: nil, state: .notPresent, powerSource: .ac, energySaverStatus: saver)
            return
        }
        let state: BatteryState = charging ? .charging : !onMains ? .discharging : full ? .full : .notCharging
        self.init(
            chargeLevel: level.isFinite ? min(max(level, 0), 1) : 0, state: state,
            powerSource: onMains ? .ac : .battery, energySaverStatus: saver)
    }
}

extension HostDisplayInfo {
    /// A screen `width` by `height` pixels as it stands now, turned `quarterTurns` quarters from its natural
    /// orientation: landscape where it is at least as wide as it is tall. A `refreshRate` of nought - the
    /// platform not saying - is none.
    public init(width: Double, height: Double, density: Double, quarterTurns: Int, refreshRate: Double) {
        let rotations: [DisplayRotation] = [.rotation0, .rotation90, .rotation180, .rotation270]
        self.init(
            width: width, height: height, density: density, orientation: width >= height ? .landscape : .portrait,
            rotation: rotations[(quarterTurns % 4 + 4) % 4], refreshRate: refreshRate > 0 ? refreshRate : nil)
    }

    /// A screen `width` by `height` pixels that turns with nothing.
    public init(width: Double, height: Double, density: Double, refreshRate: Double) {
        self.init(width: width, height: height, density: density, quarterTurns: 0, refreshRate: refreshRate)
    }
}
