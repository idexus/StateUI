// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the page tells the core it stands on: a browser on a phone or a tablet where its user points by touch, on a
/// desktop else, the application's info, and the user's appearance and its accent.
/// Design: docs/design/platforms/web/runtime.md#the-environment
@MainActor
enum WebEnvironment {
    static func report(to core: CoreLink, applicationName: String) {
        let touch = WebRelay.touchScreen
        core.setDeviceInfo(HostDeviceInfo(
            formFactor: touch > 0 ? .touchScreen(smallestWidth: touch) : .desktop, platform: "Web", model: "",
            manufacturer: "", name: "", versionString: "", deviceType: .physical))
        core.setApplicationInfo(HostApplicationInfo(
            name: applicationName, packageName: applicationName, versionString: "", buildString: ""))
        reportChanging(to: core)
    }

    /// Tells `core` what may change while the page is open: the appearance, dark or light, and its accent.
    static func reportChanging(to core: CoreLink) {
        core.setColorScheme(WebRelay.prefersDark ? .dark : .light)
        let accent = WebRelay.accentColor
        core.setAccentColor(Color(
            red: Int(accent >> 16 & 255), green: Int(accent >> 8 & 255), blue: Int(accent & 255),
            alpha: Int(accent >> 24 & 255)))
    }

    /// Calls `changed` whenever the user's appearance turns dark or light, under the listener it answers.
    static func watch(_ changed: @escaping () -> Void) -> Int32 {
        let listener = WebRelay.listener(changed)
        WebRelay.listenToAppearance(listener)
        return listener
    }
}
