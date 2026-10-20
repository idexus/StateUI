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
    /// The user's locale as it stands: the language and region, the time zone, the clock, the week, the measures and
    /// the direction words read in.
    public static var locale: HostLocaleInfo {
        let locale = Locale.current
        let hourCycle = locale.hourCycle
        return HostLocaleInfo(
            language: locale.language.languageCode?.identifier ?? "",
            region: locale.region?.identifier ?? "",
            name: locale.identifier(.bcp47),
            timeZone: TimeZone.current.identifier,
            uses24HourClock: hourCycle == .zeroToTwentyThree || hourCycle == .oneToTwentyFour,
            firstDayOfWeek: Weekday(rawValue: Int32(Calendar.current.firstWeekday - 1)) ?? .sunday,
            isMetric: locale.measurementSystem != .us,
            layoutDirection: locale.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
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
            versionString: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            buildString: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")
    }
}
