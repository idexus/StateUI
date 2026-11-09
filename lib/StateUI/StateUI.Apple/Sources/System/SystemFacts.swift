// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Network
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What Apple's platforms tell alike of the system an application runs on: the user's locale, the network, the
/// application itself.
/// Design: docs/design/platforms/apple/system.md#the-systems-facts
@_spi(Host) @MainActor
public enum SystemFacts {
    /// The user's locale as it stands: the language and region, the time zone, the clock, the week, the measures,
    /// the direction words read in, and the user's languages in order.
    public static var locale: HostLocaleInfo {
        let locale = Locale.current
        let hourCycle = locale.hourCycle
        let language = locale.identifier(.bcp47)
        let zone = TimeZone.current.identifier
        return HostLocaleInfo(
            language: language.isEmpty ? nil : LocaleTag(language),
            timeZone: zone.isEmpty ? nil : TimeZoneName(zone),
            uses24HourClock: hourCycle == .zeroToTwentyThree || hourCycle == .oneToTwentyFour,
            firstDayOfWeek: Weekday(rawValue: Int32(Calendar.current.firstWeekday - 1)) ?? .sunday,
            isMetric: locale.measurementSystem != .us,
            writingDirection: locale.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight,
            languages: Locale.preferredLanguages.map { LocaleTag($0) })
    }

    /// The wall clock at `instant` in `zone`, on the civil calendar - the Gregorian, whatever calendar the user reads
    /// days in - as `currentTime` answers it.
    /// Design: docs/design/platforms/apple/system.md#the-clock
    public static func localTime(at instant: Date = Date(), in zone: TimeZone = .current) -> LocalTime {
        let now = civil(in: zone).dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond], from: instant)
        return LocalTime(
            year: now.year ?? 0, month: now.month ?? 0, day: now.day ?? 0, hour: now.hour ?? 0,
            minute: now.minute ?? 0, second: now.second ?? 0, millisecond: (now.nanosecond ?? 0) / 1_000_000)
    }

    /// How many minutes the zone named `name` - the user's for nil - stands from UTC at noon on `day`, now for nil;
    /// nil for a name no zone has.
    public static func utcOffset(of name: String?, on day: CalendarDate?) -> Int? {
        guard let zone = name.map(TimeZone.init(identifier:)) ?? TimeZone.current else { return nil }
        let date = day.flatMap {
            civil(in: zone).date(from: DateComponents(year: $0.year, month: $0.month, day: $0.day, hour: 12))
        } ?? Date()
        return zone.secondsFromGMT(for: date) / 60
    }

    /// The Gregorian calendar in `zone`.
    private static func civil(in zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    /// What `path` reaches - the internet, only what is near, nothing - and through what.
    public static func connectivity(_ path: NWPath) -> HostConnectivityInfo {
        let access: NetworkAccess = switch path.status {
        case .satisfied: .internet
        case .unsatisfied: path.availableInterfaces.isEmpty ? .none : .local
        case .requiresConnection: .none
        @unknown default: .unknown
        }
        let kinds: [(NWInterface.InterfaceType, ConnectionProfile)] = [
            (.cellular, .cellular), (.wiredEthernet, .ethernet), (.wifi, .wifi),
        ]
        return HostConnectivityInfo(
            networkAccess: access,
            connectionProfiles: kinds.filter { kind in path.availableInterfaces.contains { $0.type == kind.0 } }
                .map(\.1))
    }

    /// The application as its bundle names it: its name shown, its identifier, its version and its build.
    public static var application: HostApplicationInfo {
        let bundle = Bundle.main
        return HostApplicationInfo(
            name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? ProcessInfo.processInfo.processName,
            packageName: bundle.bundleIdentifier ?? "",
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")
    }
}
