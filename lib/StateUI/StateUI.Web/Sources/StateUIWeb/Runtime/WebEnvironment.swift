// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the page tells the core it stands on: a browser on a desktop, and the user's appearance.
/// Design: docs/design/platforms/web/runtime.md#the-environment
@MainActor
enum WebEnvironment {
    static func report(to core: CoreLink, applicationName: String) {
        core.setDeviceInfo(HostDeviceInfo(
            formFactor: .desktop, platform: "Web", model: "", manufacturer: "", name: "", versionString: "",
            deviceType: .physical))
        core.setApplicationInfo(HostApplicationInfo(
            name: applicationName, packageName: applicationName, versionString: "", buildString: ""))
        reportChanging(to: core)
    }

    /// Tells `core` what may change while the page is open: the appearance, dark or light.
    static func reportChanging(to core: CoreLink) {
        core.setColorScheme(WebRelay.prefersDark ? .dark : .light)
    }

    /// Calls `changed` whenever the user's appearance turns dark or light.
    static func watch(_ changed: @escaping () -> Void) {
        WebRelay.listenToAppearance(WebRelay.listener(changed))
    }
}
