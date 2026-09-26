// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// What the device, the application, the user's locale, the battery, the network, the system's theme and the screen
/// are, told to the core as the host starts, and again whenever Windows says one changed.
/// Design: docs/design/platforms/winui/runtime.md#the-environment
@MainActor
enum WinUIEnvironment {
    /// Tells `core` what the host stands on: what never changes, then what may.
    static func report(to core: CoreLink) {
        if let device = HostDeviceInfo(words: facts(StateUIFactsDevice), formFactor: .desktop, platform: "Windows") {
            core.setDeviceInfo(device)
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

        if let locale = HostLocaleInfo(words: facts(StateUIFactsLocale)) { core.setLocaleInfo(locale) }

        let battery = facts(StateUIFactsBattery)
        if battery.count == 5 {
            let level = Double(battery[1]) ?? 1
            core.setBatteryInfo(HostBatteryInfo(
                present: battery[0] == "1", level: level, charging: battery[2] == "1", onMains: battery[3] == "1",
                full: level >= 1, saving: battery[4] == "1"))
        }

        let network = facts(StateUIFactsConnectivity)
        if network.count == 2 {
            core.setConnectivityInfo(HostConnectivityInfo(
                access: Int32(Double(network[0]) ?? 0), connections: Int32(Double(network[1]) ?? 0)))
        }
    }

    /// Tells `core` the screen `window` stands on.
    static func reportDisplay(to core: CoreLink, window: WinUIWindow) {
        let display = facts(StateUIFactsDisplay, window: window.handle)
        guard display.count == 4 else { return }

        core.setDisplayInfo(HostDisplayInfo(
            width: Double(display[0]) ?? 0, height: Double(display[1]) ?? 0, density: Double(display[2]) ?? 1,
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
