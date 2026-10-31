// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the page tells the core it stands on: a browser on a phone or a tablet where its user points by touch, on a
/// desktop else, the application's info, the user's appearance and its accent, the user's locale, and what the user
/// asked of motion and contrast.
/// Design: docs/design/platforms/web/runtime.md#the-environment
@MainActor
enum WebEnvironment {
    static func report(to core: CoreLink, applicationName: String) {
        let touch = WebRelay.touchScreen
        core.setDeviceInfo(HostDeviceInfo(
            formFactor: touch > 0 ? .touchScreen(smallestWidth: touch) : .desktop, platform: "Web", model: "",
            manufacturer: "", name: "", versionString: "", isVirtual: nil))
        core.setApplicationInfo(HostApplicationInfo(
            name: applicationName, packageName: applicationName, versionString: "", buildString: ""))
        reportChanging(to: core)
    }

    /// Tells `core` what may change while the page is open: the appearance, dark or light, its accent, the locale,
    /// and less motion and more contrast - a page is told of no screen reader and no scale of the system's words.
    static func reportChanging(to core: CoreLink) {
        if let locale = locale(WebRelay.localeWords) { core.setLocaleInfo(locale) }
        core.setColorScheme(WebRelay.prefersDark ? .dark : .light)
        core.setAccentColor(Color(argb: WebRelay.accentColor))
        core.setAccessibilityInfo(HostAccessibilityInfo(
            reducesMotion: WebRelay.reducesMotion, prefersHigherContrast: WebRelay.prefersMoreContrast,
            isScreenReaderOn: false, textScale: 1))
    }

    /// Calls `changed` whenever the user's appearance turns dark or light, the user's languages change, or less
    /// motion or more contrast is asked for, under the listener it answers.
    static func watch(_ changed: @escaping () -> Void) -> Int32 {
        let listener = WebRelay.listener(changed)
        WebRelay.listenToAppearance(listener)
        WebRelay.listenToLocale(listener)
        WebRelay.listenToAccessibility(listener)
        return listener
    }

    /// The user's locale from what the browser says of it (`locale_words`): the language the user put first, its
    /// region - the likeliest where the user named none - the zone, a 24-hour clock where the language's hours run
    /// from 0, the week's first day where the browser knows it, metric measures but in the three countries of none,
    /// and the writing's direction; nil for words that say no language.
    /// Design: docs/design/platforms/web/runtime.md#the-environment
    nonisolated static func locale(_ words: [String]) -> HostLocaleInfo? {
        guard words.count >= 6, !words[0].isEmpty else { return nil }
        let filled = words[1].split(separator: "-").map(String.init)
        let region = filled.dropFirst().first { $0.count == 2 && $0 == $0.uppercased() } ?? ""
        let firstDay = Int32(words[4]).map { Weekday(rawValue: $0 % 7) ?? .sunday } ?? .sunday
        return HostLocaleInfo(
            language: filled.first?.lowercased() ?? "", region: region, name: words[0], timeZone: words[2],
            uses24HourClock: words[3] == "h23" || words[3] == "h24", firstDayOfWeek: firstDay,
            isMetric: !["US", "LR", "MM"].contains(region),
            layoutDirection: words[5] == "rtl" ? .rightToLeft : .leftToRight, languages: Array(words.dropFirst(6)))
    }
}
