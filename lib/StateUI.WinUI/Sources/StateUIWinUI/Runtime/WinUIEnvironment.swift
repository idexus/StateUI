// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// What the device, the application, the user's locale, the battery, the network, the system's theme and the screen
/// are, told to the core as the host starts, and again whenever Windows says one changed.
/// Design: docs/design/platforms/winui/runtime.md#the-environment
@MainActor
enum WinUIEnvironment {
    /// Tells `core` what the host stands on: what never changes, then what may.
    static func report(to core: CoreLink) {
        let device = facts(StateUIFactsDevice)
        if device.count == 5 {
            core.setDeviceInfo(HostDeviceInfo(
                formFactor: .desktop, platform: "Windows", model: device[0], manufacturer: device[1],
                name: device[2], versionString: device[3], deviceType: device[4] == "1" ? .virtual : .physical))
        }
        let application = facts(StateUIFactsApplication)
        if application.count == 4 {
            core.setApplicationInfo(HostApplicationInfo(
                name: application[0], packageName: application[1], versionString: application[2],
                buildString: application[3]))
        }
        reportChanging(to: core)
    }

    /// Tells `core` the theme, the user's locale, the battery and the network, as they stand now.
    static func reportChanging(to core: CoreLink) {
        let theme = facts(StateUIFactsTheme)
        core.setTheme(theme.first == "1" ? .dark : .light)

        let locale = facts(StateUIFactsLocale)
        if locale.count == 8 {
            core.setLocaleInfo(HostLocaleInfo(
                language: locale[0], region: locale[1], name: locale[2], timeZone: locale[3],
                uses24HourClock: locale[4] == "1",
                firstDayOfWeek: Weekday(rawValue: Int32(Double(locale[5]) ?? 0)) ?? .sunday,
                isMetric: locale[6] == "1",
                layoutDirection: locale[7] == "1" ? .rightToLeft : .leftToRight))
        }

        let battery = facts(StateUIFactsBattery)
        if battery.count == 5 {
            let present = battery[0] == "1", charging = battery[2] == "1", mains = battery[3] == "1"
            let level = Double(battery[1]) ?? 1
            let state: BatteryState = !present ? .notPresent
                : charging ? .charging : !mains ? .discharging : level >= 1 ? .full : .notCharging
            core.setBatteryInfo(HostBatteryInfo(
                chargeLevel: level, state: state, powerSource: mains ? .ac : .battery,
                energySaverStatus: battery[4] == "1" ? .on : .off))
        }

        let network = facts(StateUIFactsConnectivity)
        if network.count == 2 {
            let bits = Int(Double(network[1]) ?? 0)
            let kinds: [(bit: Int, profile: ConnectionProfile)] = [
                (1, .bluetooth), (2, .cellular), (4, .ethernet), (8, .wiFi),
            ]
            core.setConnectivityInfo(HostConnectivityInfo(
                networkAccess: NetworkAccess(rawValue: Int32(Double(network[0]) ?? 0)) ?? .unknown,
                connectionProfiles: kinds.filter { bits & $0.bit != 0 }.map(\.profile)))
        }
    }

    /// Tells `core` the screen `window` stands on.
    static func reportDisplay(to core: CoreLink, window: WinUIWindow) {
        let display = facts(StateUIFactsDisplay, window: window.handle)
        guard display.count == 4 else { return }

        let width = Double(display[0]) ?? 0, height = Double(display[1]) ?? 0
        core.setDisplayInfo(HostDisplayInfo(
            width: width, height: height, density: Double(display[2]) ?? 1,
            orientation: width >= height ? .landscape : .portrait, rotation: .rotation0,
            refreshRate: Double(display[3]) ?? 60))
    }

    /// One group of facts, as the relay reads them.
    private static func facts(_ kind: StateUIFacts, window: StateUIObjectRef? = nil) -> [String] {
        let length = Int(stateui_winui_facts(kind, window, nil, 0))
        var bytes = [CChar](repeating: 0, count: length + 1)
        _ = stateui_winui_facts(kind, window, &bytes, Int32(bytes.count))
        let text = String(decoding: bytes.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return text.split(separator: "\u{1F}", omittingEmptySubsequences: false).dropLast().map(String.init)
    }
}
