// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK
import Glibc

/// What the machine says of the user's locale, its power and its network, as the desktop's own services keep them:
/// the C library's locale, UPower and the power profiles, GIO's network monitor and NetworkManager.
/// Design: docs/design/platforms/gtk/runtime.md#the-environment
extension GTKEnvironment {
    /// The local zone as it stands now - the one `TZ` names, else the machine's - which the locale, the clock and a
    /// local offset all read: GLib's own local zone is kept from its first reading. The caller lets it go.
    /// Design: docs/design/platforms/gtk/runtime.md#the-environment
    static func localZone() -> OpaquePointer {
        let named = g_getenv("TZ").map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : g_time_zone_new_identifier($0) }
        return named ?? g_time_zone_new_identifier(nil) ?? g_time_zone_new_local()!
    }

    /// The user's locale: the language and region GLib reads from the environment, the local zone, the clock, the
    /// week and the measures of the C library's locale, and the user's languages in order.
    static var locale: HostLocaleInfo {
        let names = languageNames
        let name = tag(of: names.first ?? "C")
        let zone = localZone()
        defer { g_time_zone_unref(zone) }
        let time = String(cString: nl_langinfo(nl_item(T_FMT)))
        let zoneName = String(cString: g_time_zone_get_identifier(zone))
        return HostLocaleInfo(
            language: name.isEmpty ? nil : LocaleTag(name),
            timeZone: zoneName.isEmpty ? nil : TimeZoneName(zoneName),
            uses24HourClock: !time.contains("%r") && !time.contains("%I") && !time.contains("%p"),
            firstDayOfWeek: firstDayOfWeek,
            isMetric: nl_langinfo(nl_item(_NL_MEASUREMENT_MEASUREMENT)).pointee != 2,
            writingDirection: gtk_get_locale_direction() == GTK_TEXT_DIR_RTL ? .rightToLeft : .leftToRight,
            languages: languages(of: names).map { LocaleTag($0) })
    }

    /// The locale names GLib reads from the environment, most wanted first: `pl_PL.UTF-8`, `pl_PL`, `pl`, `C`.
    private static var languageNames: [String] {
        guard var at = g_get_language_names() else { return [] }
        var names: [String] = []
        while let name = at.pointee {
            names.append(String(cString: name))
            at += 1
        }
        return names
    }

    /// The user's languages as tags, most wanted first, from the locale `names` GLib reads: each said once, without
    /// its codeset and modifier; the C locale is no language.
    static func languages(of names: [String]) -> [String] {
        var tags: [String] = []
        for name in names {
            let tag = tag(of: name)
            guard tag != "C", tag != "POSIX", !tags.contains(tag) else { continue }
            tags.append(tag)
        }
        return tags
    }

    /// A locale name as a tag: `pl_PL.UTF-8@latin` is `pl-PL`.
    private static func tag(of name: String) -> String {
        let bare = name.split(whereSeparator: { $0 == "." || $0 == "@" }).first.map(String.init) ?? name
        return bare.split(separator: "_").joined(separator: "-")
    }

    /// The first day of the week as the C library's locale counts it, from the week's origin - a Sunday or a Monday
    /// in 1997 - as GTK's own calendar reads it.
    private static var firstDayOfWeek: Weekday {
        let first = Int(nl_langinfo(nl_item(_NL_TIME_FIRST_WEEKDAY)).pointee)
        let origin = Int(bitPattern: UnsafeRawPointer(nl_langinfo(nl_item(_NL_TIME_WEEK_1STDAY))))
        let originDay = origin == 19_971_201 ? 1 : 0
        return Weekday(rawValue: Int32((originDay + first - 1 + 7) % 7)) ?? .sunday
    }

    /// The machine's power as UPower's display device has it, and whether the power profiles save energy; no battery
    /// where UPower stands nowhere.
    static var battery: HostBatteryInfo {
        let state = read(services.display, "State") { g_variant_get_uint32($0) } ?? 0
        return HostBatteryInfo(
            present: read(services.display, "IsPresent") { g_variant_get_boolean($0) != 0 } ?? false,
            level: (read(services.display, "Percentage") { g_variant_get_double($0) } ?? 0) / 100,
            charging: state == 1 || state == 5,
            onMains: read(services.power, "OnBattery") { g_variant_get_boolean($0) == 0 } ?? true,
            full: state == 4,
            saving: services.profiles.map { g_power_profile_monitor_get_power_saver_enabled($0) != 0 } ?? false)
    }

    /// The network as GIO's monitor has it, and the connection NetworkManager says is the primary one.
    static var connectivity: HostConnectivityInfo {
        let monitor = g_network_monitor_get_default()
        let access: NetworkAccess
        if monitor.map({ g_network_monitor_get_network_available($0) != 0 }) != true {
            access = .none
        } else {
            access = switch g_network_monitor_get_connectivity(monitor) {
            case G_NETWORK_CONNECTIVITY_FULL: .internet
            case G_NETWORK_CONNECTIVITY_LIMITED, G_NETWORK_CONNECTIVITY_PORTAL: .constrainedInternet
            default: .local
            }
        }
        let kind = read(services.network, "PrimaryConnectionType") { String(cString: g_variant_get_string($0, nil)) }
        let bits: Int32 = switch kind {
        case "bluetooth": 1
        case "gsm", "cdma": 2
        case "802-3-ethernet": 4
        case "802-11-wireless": 8
        default: 0
        }
        return HostConnectivityInfo(access: access.rawValue, connections: bits)
    }

    /// The desktop's services the environment reads - UPower's display device and itself and NetworkManager, each a
    /// proxy on the system bus, and GIO's power profile monitor - each nil where it stands nowhere.
    private static let services = (
        display: proxy("org.freedesktop.UPower", "/org/freedesktop/UPower/devices/DisplayDevice", "org.freedesktop.UPower.Device"),
        power: proxy("org.freedesktop.UPower", "/org/freedesktop/UPower", "org.freedesktop.UPower"),
        network: proxy("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager"),
        profiles: g_power_profile_monitor_dup_default())

    /// A proxy of `name`'s object at `path` on the system bus, which keeps its properties up to date; nil where there
    /// is no such bus.
    private static func proxy(_ name: String, _ path: String, _ interface: String) -> UnsafeMutablePointer<GDBusProxy>? {
        g_dbus_proxy_new_for_bus_sync(G_BUS_TYPE_SYSTEM, STATEUI_DBUS_PROXY_FLAGS_DO_NOT_AUTO_START, nil, name, path, interface, nil, nil)
    }

    /// What `proxy` holds of `property` now, read by `value`; nil where it holds none.
    private static func read<Value>(
        _ proxy: UnsafeMutablePointer<GDBusProxy>?, _ property: String, _ value: (OpaquePointer) -> Value
    ) -> Value? {
        guard let proxy, let variant = g_dbus_proxy_get_cached_property(proxy, property) else { return nil }
        defer { g_variant_unref(variant) }
        return value(variant)
    }

    /// Calls `changed` whenever the power, the power profile or the network change.
    static func watchMachine(_ changed: @escaping @MainActor () -> Void) {
        onMachineChange = changed
        guard !watchingMachine else { return }
        watchingMachine = true
        for proxy in [services.display, services.power, services.network].compactMap({ $0 }) {
            connectSignal(UnsafeMutableRawPointer(proxy), "g-properties-changed", number: 0) {
                (_: UnsafeMutableRawPointer?, _: UnsafeMutableRawPointer?, _: gpointer?) in
                MainActor.assumeIsolated { GTKEnvironment.onMachineChange?() }
            }
        }
        if let monitor = g_network_monitor_get_default() {
            connectSignal(UnsafeMutableRawPointer(monitor), "network-changed", number: 0) {
                (_: UnsafeMutableRawPointer?, _: UnsafeMutableRawPointer?, _: gpointer?) in
                MainActor.assumeIsolated { GTKEnvironment.onMachineChange?() }
            }
        }
        if let profiles = services.profiles {
            connectNotify(UnsafeMutableRawPointer(profiles), "power-saver-enabled", number: 0) { _, _, _ in
                MainActor.assumeIsolated { GTKEnvironment.onMachineChange?() }
            }
        }
    }

    private static var watchingMachine = false
    private static var onMachineChange: (@MainActor () -> Void)?
}
